#!/bin/bash

# Run the entrypoint script that comes with the web server image to set up the environment (users, permissions)
/usr/local/bin/nginx-fpm-entrypoint.sh


# Setup October CMS
CMS_REDO_PLUGINS=${CMS_REDO_PLUGINS:-false}
CMS_REDO_THEMES=${CMS_REDO_THEMES:-false}
CMS_PLUGINS=${CMS_PLUGINS:-}
CMS_THEMES=${CMS_THEMES:-}

### Functions ###

log_entry()
{
    if grep -qi ^"$1" storage/logs/docker-october.log ; then
        REPLACEMENT=$@
        sed -i "s#$1.*#$REPLACEMENT#g" storage/logs/docker-october.log
    else
        echo "$@" >> storage/logs/docker-october.log
    fi
    return 0
}

get_date_time()
{
    echo "$(date '+%d/%m/%Y %H:%M:%S')"
    return 0
}

# Check to see if the $CMS_PLUGINS variable has been changed since the last run
plugins_changed()
{
    IFS=', ' read -r -a REQUESTED_PLUGINS <<< "$CMS_PLUGINS"
    CURRENT_PLUGINS="$(grep -i "Plugins installed:" storage/logs/docker-october.log | sed 's/^.*:\s //')"
    if [[ "${CURRENT_PLUGINS}" != "${REQUESTED_PLUGINS[@]}" ]] ; then
     return 0
    fi
    false
}

themes_changed()
{
    IFS=', ' read -r -a REQUESTED_THEMES <<< "$CMS_THEMES"
    CURRENT_THEMES="$(grep -i "Themes installed:" storage/logs/docker-october.log | sed 's/^.*:\s //')"
    if [[ "${CURRENT_THEMES}" != "${REQUESTED_THEMES[@]}" ]] ; then
     return 0
    fi
    false
}


install_plugins()
{
    # If $CMS_PLUGINS is set
    if [ ! -z $CMS_PLUGINS ] ; then
        IFS=', ' read -r -a PLUGIN_ARRAY <<< "$CMS_PLUGINS"
        for plugin in ${PLUGIN_ARRAY[@]}
            do
               sleep 5
               echo "going to install $plugin"
               php artisan -vvv plugin:install $plugin
            done
        log_entry "Plugins Installed: " ${PLUGIN_ARRAY[@]}
        log_entry "Plugins last installed: " "$(get_date_time)"
    fi
}

install_themes()
{
    # If $CMS_THEMES is set
    if [ ! -z $CMS_THEMES ] ; then
        IFS=', ' read -r -a THEME_ARRAY <<< "$CMS_THEMES"
        for theme in ${THEME_ARRAY[@]}
            do
               php artisan theme:install $theme
            done
        log_entry "Themes Installed: " ${THEME_ARRAY[@]}
        log_entry "Themes last installed: " "$(get_date_time)"
    fi
}

install_git_repo()
{
    local target=$1 ; local domain=$2 ; local username=$3 ; local token=$4 ; local repos=$5
    if [ -z $repos ] ; then return 1 ; fi

    IFS=', ' read -r -a requested_repos <<< "$repos"

    for repo in ${requested_repos[@]} ; do

        # We should have exactly 0 or 1 ":" in these strings. Move on if not
        req_repo_colons=$(awk -F":" '{print NF-1}' <<< "${repo}")
        if [ ! $req_repo_colons -le 1 ] ; then continue ; fi

        IFS=': ' read -r -a repo_rename_split <<< "$repo"
        local git_path=${repo_rename_split[0]}
        local item_path=${repo_rename_split[1]}

        if [ -z $git_path ] ; then continue ; fi
        if [ -z $item_path ] ; then item_path=${git_path} ; fi

        local git_path_fsl=$(awk -F"/" '{print NF-1}' <<< "${git_path}")
        local item_path_fsl=$(awk -F"/" '{print NF-1}' <<< "${item_path}")
        # We should have exactly 1 "/" in the git path
        if [ ! $git_path_fsl -eq 1 ] ; then continue ; fi

        # We should have exactly 1 "/" in the item path for plugins
        if [ $target = "plugins" ] && [ ! $item_path_fsl -eq 1 ] ; then continue ; fi

        # We should have 0 or 1 "/" in the item path for themes
        if [ $target = "themes" ] && [ ! $item_path_fsl -le 1 ] ; then continue ; fi

        IFS='/ ' read -r -a git_split <<< "$git_path"
        local git_namespace=${git_split[0]}
        local git_repo=${git_split[1]}
        if [ -z $git_namespace ] || [ -z $git_repo ] ; then continue ; fi


        if [ "$target" = "plugins" ] ; then
            IFS='/ ' read -r -a item_split <<< "$item_path"
            local item_namespace=${item_split[0]}
            local item_repo=${item_split[1]}
            if [ -z $item_namespace ] || [ -z $item_repo ] ; then continue ; fi
            dest_path="$target/$item_namespace/$item_repo"
        fi

        if [ "$target" = "themes" ] ; then
            dest_path="$target/${item_path//\//-}"
        fi

        # We should have a proper destination path set but just in case...
        if [ -z $dest_path ] ; then continue ; fi

        # Clone if the destination path does not exist otherwise just pull
        if [ ! -e "$dest_path" ]; then
            git clone "https://$username:$token@$domain/$git_namespace/$git_repo" "$dest_path"
        else
            (cd "$dest_path" && git pull)
        fi

        # Install composer dependencies
        if [ -f "${dest_path}/composer.json" ] ; then
          (cd "$dest_path" && composer install)
        fi

    done
}

config_wants_database()
{
  DB=$(grep DB_CONNECTION /var/www/app/.env | cut -d '=' -f2)
  if [ -z $DB ] || [ "${DB,,}" = "null" ] || [ "${DB,,}" = "none" ]
  then
          false
  else
          return 0
  fi
}


### End Functions ###

# Move things back to their proper places. The build moved them to enable the entire october cms app to be a volume mount if desired

# We have an archive of the app structure so lets just extract it (for bind mount app dir)
# This is DESTRUCTIVE. Do not modify core files because they will be OVERWRITTEN on container start
# Plugins, themes, storage, config and .env file will not be affected
echo "Setting up app directory..."
# Extract the core files as they were installed
echo "Writing core files from install..."
tar -zxf /var/www/app.tar.gz -C /var/www/ > /dev/null 2>&1
# Extract the overlay archive - Local changes in data/app when the image was built
echo "Applying local changes from build time"
tar -zxf /var/www/app-overlay.tar.gz -C /var/www/ > /dev/null 2>&1

### Delete this according to notes in Dockerfile - Overlay method preferred
### tar -k -zxf /var/www/app/config.tar.gz -C /var/www/app/ > /dev/null 2>&1

# Check we have a valid .env file. User is expected to mount it but if it's missing we can create one

if [ ! -s /var/www/app/.env ] ; then
  cat /var/www/app/.env-original > /var/www/app/.env
fi

# Set the application key
if [ -z $(grep APP_KEY /var/www/app/.env | cut -d '=' -f2) ] ; then
  # work around sed inode problem in docker
  cp /var/www/app/.env /var/www/app/.env-temp
  sed -i "s#APP_KEY=.*#APP_KEY=$(php artisan key:generate --show)#g" /var/www/app/.env-temp
  cat /var/www/app/.env-temp > /var/www/app/.env
  rm /var/www/app/.env-temp
fi

# Create log file if it's not present
touch storage/logs/docker-october.log

# Create a sqlite database file - If this location isn't a bind mount/volume it WILL NOT PERSIST
touch /var/www/app/storage/app/database.sqlite

# Log entry for the most recent processing of environment variables and config writing
log_entry "Config last processed: " "$(get_date_time)"

# Bring up the database and install some plugins. Skip this if no database specified
if config_wants_database ; then
    DB_MAX_TRIES=5
    DB_SLEEP=5
    DB_UP=0
    DB_ATTEMPT=0
    echo "Attempting to connect to database..."

    while [ $DB_ATTEMPT -le $DB_MAX_TRIES ] ; do
      php artisan october:migrate
      if [ $? -eq 0 ] ; then
        DB_UP=1
        echo "Database is up"
        break
      else
        DB_ATTEMPT=$((DB_ATTEMPT+1))
        echo "Database is not ready. Sleeping for $DB_SLEEP seconds"
        sleep $DB_SLEEP
      fi
    done

    if [ $DB_UP -eq 1 ] ; then
      # If plugins have not already been installed or we have set $CMS_REDO_PLUGINS=true
      if plugins_changed ; then CMS_REDO_PLUGINS=true ; fi
      if ! grep -qi '^Plugins last installed:' storage/logs/docker-october.log || [ $CMS_REDO_PLUGINS = "true"  ]; then
          install_plugins
      fi

      # If themes have not already been installed or we have set $CMS_REDO_THEMES=true
      if themes_changed ; then CMS_REDO_THEMES=true ; fi
      if ! grep -qi '^Themes last installed:' storage/logs/docker-october.log || [ "$CMS_REDO_THEMES" = "true"  ]; then
          install_themes
      fi

      # Clone git repositories if we have any
      for i in {0..99} ; do
          domain=$"GIT_${i}_DOMAIN"
          username=$"GIT_${i}_USERNAME"
          token=$"GIT_${i}_TOKEN"
          plugin_repos=$"GIT_${i}_PLUGIN_REPOS"
          theme_repos=$"GIT_${i}_THEME_REPOS"
          if [ ! -z ${!domain} ] && [ ! -z ${!username} ] && [ ! -z ${!token} ] ; then
              if [ ! -z ${!plugin_repos} ] || [ ! -z ${!theme_repos} ] ; then
                  install_git_repo "plugins" "${!domain}" "${!username}" "${!token}" "${!plugin_repos}"
                  install_git_repo "themes" "${!domain}" "${!username}" "${!token}" "${!theme_repos}"
              fi
          fi
      done

      # Re-run migrations after git clones
      php artisan october:migrate
      else
        echo "Could not connect to the database. Check your configuration"
    fi
fi

# Delete the demo theme if desired.
if [ "$CMS_FRESH_INSTALL" = 'true' ] && [ -d "themes/demo" ] ; then
    echo "commented out for now"
    #php artisan october:fresh
    #rm -rf plugins/october/demo
fi

## Set the active theme
if [ ! -z $CMS_ACTIVE_THEME ] ; then
    echo "commented out for now"
    #php artisan theme:use $CMS_ACTIVE_THEME
fi

echo "Setting permissions ($USER_UID:$USER_GID) ..."
chown -R $USER_UID:$USER_GID /var/www/app

exec "$@"
