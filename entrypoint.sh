#!/bin/bash

# Run the entrypoint script that comes with the web server image to set up the environment
nginx-fpm-entrypoint.sh

# Setup October CMS
OC_APP_DEBUG=${OC_APP_DEBUG:-true}
OC_APP_KEY=${OC_APP_KEY:-}
OC_APP_URL=${OC_APP_URL:-http://localhost}
OC_DB_CONNECTION=${OC_DB_CONNECTION:-sqlite}
OC_DB_HOST=${OC_DB_CONNECTION:-mysql}
OC_DB_PORT=${OC_DB_PORT:-3306}
OC_DB_DATABASE=${OC_DB_DATABASE:-october}
OC_DB_USERNAME=${OC_DB_USERNAME:-october}
OC_DB_PASSWORD=${OC_DB_PASSWORD:-october}
OC_REDIS_HOST=${OC_REDIS_HOST:-redis}
OC_REDIS_PASSWORD=${OC_REDIS_PASSWORD:-}
OC_CACHE_DRIVER=${OC_CACHE_DRIVER:-file}
OC_SESSION_DRIVER=${OC_SESSION_DRIVER:-file}
OC_QUEUE_DRIVER=${OC_QUEUE_DRIVER:-sync}
OC_MAIL_DRIVER=${OC_MAIL_DRIVER:-mail}
OC_MAIL_HOST=${OC_MAIL_HOST:-smtp.mailgun.org}
OC_MAIL_PORT=${OC_MAIL_PORT:-587}
OC_MAIL_ENCRYPTION=${OC_MAIL_ENCRYPTION:-tls}
OC_MAIL_USERNAME=${OC_MAIL_USERNAME:-null}
OC_MAIL_PASSWORD=${OC_MAIL_PASSWORD:-null}
OC_ROUTES_CACHE=${OC_ROUTES_CACHE:-false}
OC_ASSET_CACHE=${OC_ASSET_CACHE:-false}
OC_LINK_POLICY=${OC_LINK_POLICY:-detect}
OC_ENABLE_CSRF=${OC_ENABLE_CSRF:-true}
OC_FRESH_INSTALL=${OC_FRESH_INSTALL:-false}
OC_REDO_PLUGINS=${OC_REDO_PLUGINS:-false}
OC_REDO_THEMES=${OC_REDO_THEMES:-false}
OC_PLUGINS=${OC_PLUGINS:-}
OC_THEMES=${OC_THEMES:-}

### Functions ###

log_entry()
{
    if grep -qi ^"$1" storage/logs/docker-october.log ; then
        REPLACEMENT=$@
        sed -i "s#$1.*#$REPLACEMENT#g" storage/logs/docker-october.log
    else
        echo "$@" >> storage/logs/docker-october.log
    fi
}

get_date_time()
{
    echo "$(date '+%d/%m/%Y %H:%M:%S')"
    return 0
}

# Check to see if the $OC_PLUGINS variable has been changed since the last run
plugins_changed()
{
    IFS=', ' read -r -a REQUESTED_PLUGINS <<< "$OC_PLUGINS"
    CURRENT_PLUGINS="$(grep -i "Plugins installed:" storage/logs/docker-october.log | sed 's/^.*:\s //')"
    if [[ "${CURRENT_PLUGINS}" != "${REQUESTED_PLUGINS[@]}" ]] ; then
     return 0
    fi
    return 1
}

themes_changed()
{
    IFS=', ' read -r -a REQUESTED_THEMES <<< "$OC_THEMES"
    CURRENT_THEMES="$(grep -i "Themes installed:" storage/logs/docker-october.log | sed 's/^.*:\s //')"
    if [[ "${CURRENT_THEMES}" != "${REQUESTED_THEMES[@]}" ]] ; then
     return 0
    fi
    return 1
}


install_plugins()
{
    # If $OC_PLUGINS is set
    if [ ! -z $OC_PLUGINS ] ; then
        IFS=', ' read -r -a PLUGIN_ARRAY <<< "$OC_PLUGINS"
        for plugin in ${PLUGIN_ARRAY[@]}
            do
               php artisan plugin:install $plugin
            done
        log_entry "Plugins Installed: " ${PLUGIN_ARRAY[@]}
        log_entry "Plugins last installed: " "$(get_date_time)"
    fi
}

install_themes()
{
    # If $OC_THEMES is set
    if [ ! -z $OC_THEMES ] ; then
        IFS=', ' read -r -a THEME_ARRAY <<< "$OC_THEMES"
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
            return #(cd "$dest_path" && git pull)
        fi
    done
}

### End Functions ###

# Create log file if it's not present
touch storage/logs/docker-october.log

# Generate a key before we create a .env file so it gets carried over
if [ -z $OC_APP_KEY ] & [ ! -f ".env" ] ; then
    php artisan key:generate
fi

# Make sure we have a .env file to edit or nothing is going to work properly
if [ ! -f .env ] ; then
    php artisan october:env
fi


# If we're using sqlite (the default), make sure we have a file to use
if [ "$OC_DB_CONNECTION" = "sqlite" ] ; then
    if [ ! -e "$OC_DB_DATABASE" ] ; then
        touch "$OC_DB_DATABASE"
        chown "$USER_UID:$USER_UID" "$OC_DB_DATABASE" # Inherited $USER_UID from nginx/php
    fi
fi

# TODO check connection for other database types. Maybe one day...
# For now it doesn't matter. If it doesn't connect then we will soon find out


# Only replace the app key if we have one set by env.
if [ ! -z $OC_APP_KEY ] ; then
    sed -i "s#APP_KEY=.*#APP_KEY=$OC_APP_KEY#g" .env
fi

# Edit the rest of the .env configuration
sed -i "s#APP_DEBUG=.*#APP_DEBUG=$OC_APP_DEBUG#g" .env
sed -i "s#APP_URL=.*#APP_URL=$OC_APP_URL#g" .env
sed -i "s#DB_CONNECTION=.*#DB_CONNECTION=$OC_DB_CONNECTION#g" .env
sed -i "s#DB_HOST=.*#DB_HOST=$OC_DB_HOST#g" .env
sed -i "s#DB_PORT=.*#DB_PORT=$OC_DB_PORT#g" .env
sed -i "s#DB_DATABASE=.*#DB_DATABASE=$OC_DB_DATABASE#g" .env
sed -i "s#DB_USERNAME=.*#DB_USERNAME=$OC_DB_USERNAME#g" .env
sed -i "s#DB_PASSWORD=.*#DB_PASSWORD=$OC_DB_PASSWORD#g" .env
sed -i "s#REDIS_HOST=.*#REDIS_HOST=$OC_REDIS_HOST#g" .env
sed -i "s#REDIS_PASSWORD=.*#REDIS_PASSWORD=$OC_REDIS_PASSWORD#g" .env
sed -i "s#CACHE_DRIVER=.*#CACHE_DRIVER=$OC_CACHE_DRIVER#g" .env
sed -i "s#SESSION_DRIVER=.*#SESSION_DRIVER=$OC_SESSION_DRIVER#g" .env
sed -i "s#QUEUE_DRIVER=.*#QUEUE_DRIVER=$OC_QUEUE_DRIVER#g" .env
sed -i "s#MAIL_DRIVER=.*#MAIL_DRIVER=$OC_MAIL_DRIVER#g" .env
sed -i "s#MAIL_HOST=.*#MAIL_HOST=$OC_MAIL_HOST#g" .env
sed -i "s#MAIL_PORT=.*#MAIL_PORT=$OC_MAIL_PORT#g" .env
sed -i "s#MAIL_ENCRYPTION=.*#MAIL_ENCRYPTION=$OC_MAIL_ENCRYPTION#g" .env
sed -i "s#MAIL_USERNAME=.*#MAIL_USERNAME=$OC_MAIL_USERNAME#g" .env
sed -i "s#MAIL_PASSWORD=.*#MAIL_PASSWORD=$OC_MAIL_PASSWORD#g" .env
sed -i "s#ROUTES_CACHE=.*#ROUTES_CACHE=$OC_ROUTES_CACHE#g" .env
sed -i "s#ASSET_CACHE=.*#ASSET_CACHE=$OC_ASSET_CACHE#g" .env
sed -i "s#LINK_POLICY=.*#LINK_POLICY=$OC_LINK_POLICY#g" .env
sed -i "s#ENABLE_CSRF=.*#ENABLE_CSRF=$OC_ENABLE_CSRF#g" .env


# Log entry for the most recent processing of environment variables and config writing
log_entry "Config last processed: " "$(get_date_time)"

# Bring up the database and install some plugins
if [ "$OC_DB_CONNECTION" != "none" ] ; then
    # Always do this because we want to run migrations if necessary
    php artisan october:up

    # If plugins have not already been installed or we have set $OC_REDO_PLUGINS=true
    if plugins_changed ; then OC_REDO_PLUGINS=true ; fi
    if ! grep -qi '^Plugins last installed:' storage/logs/docker-october.log || [ $OC_REDO_PLUGINS = "true"  ]; then
        install_plugins
    fi

    # If themes have not already been installed or we have set $OC_REDO_THEMES=true
    if themes_changed ; then OC_REDO_THEMES=true ; fi
    if ! grep -qi '^Themes last installed:' storage/logs/docker-october.log || [ "$OC_REDO_THEMES" = "true"  ]; then
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
    php artisan october:up

fi

# Delete the demo theme
if [ "$OC_FRESH_INSTALL" = 'true' ] && [ -d "themes/october/demo" ] ; then
    php artisan october:fresh
fi

# vars set by nginx-fpm-entrypoint.sh if not overridden here
chown -R $USER_UID:$USER_GID /var/www/app

exec "$@"
