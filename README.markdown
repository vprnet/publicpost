He Said She Said Application

Note: These instructions apply to a fresh install on OS X 10.8.2.

(1) Install Xcode 4.5.1 (available in the App Store)
(2) Install Xcode Command Line Tools (Xcode -> Preferences -> Downloads -> Command Line Tools -> Install)
(3) Install Homebrew:

    ruby -e "$(curl -fsSkL raw.github.com/mxcl/homebrew/go)"
    sudo vi /etc/paths (move /usr/local/bin to top of the file and save it)
    brew doctor
    brew update

(4) Install Ruby Version Manager (RVM):

    \curl -L https://get.rvm.io | bash -s stable

(5) Install libksba (http://www.gnupg.org/related_software/libksba/index.en.html):

    brew install libksba

(6) Install GCC 4.2:

    brew tap homebrew/dupes
    brew install autoconf automake apple-gcc42
    cd /usr/local; sudo ln -s /usr/local/bin/gcc-4.2

(7) Install Ruby 1.9.3:

    rvm install 1.9.3
    rvm use 1.9.3 --default

(8) Install PostgreSQL:

    brew install postgresql
    initdb /usr/local/var/postgres
    cp /usr/local/Cellar/postgresql/9.2.1/homebrew.mxcl.postgresql.plist ~/Library/LaunchAgents/
    launchctl load -w ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist

(9) Install Redis:

    brew install redis
    sudo mkdir /var/log/redis
    sudo chmod a+w /var/log/redis/
    cp /usr/local/etc/redis.conf ~/Library/LaunchAgents
    vi ~/Library/LaunchAgents/redis.conf (uncomment and set the "maxclients" configuration parameter to 10)
    vi ~/Library/LaunchAgents/io.redis.server.plist (replace [username] with your OS X username)

        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
          "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
          <dict>
            <key>Label</key>
            <string>io.redis.server</string>
            <key>ProgramArguments</key>
            <array>
              <string>/usr/local/bin/redis-server</string>
              <string>/Users/[username]/Library/LaunchAgents/redis.conf</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>WorkingDirectory</key>
            <string>/usr/local/bin</string>
            <key>StandardErrorPath</key>
            <string>/var/log/redis/error.log</string>
            <key>StandardOutPath</key>
            <string>/var/log/redis/output.log</string>
          </dict>
        </plist>

    launchctl load ~/Library/LaunchAgents/io.redis.server.plist

(10) Install ElasticSearch:
    brew install elasticsearch
    cp /usr/local/Cellar/elasticsearch/0.19.10/homebrew.mxcl.elasticsearch.plist ~/Library/LaunchAgents/
    launchctl load -wF ~/Library/LaunchAgents/homebrew.mxcl.elasticsearch.plist

(11) Install and configure the Heroku Toolbelt:
    https://toolbelt.heroku.com
    heroku login

(12) Create a DB user for the application:

    createuser --interactive he-said-she-said
    Shall the new role be a superuser? (y/n) n
    Shall the new role be allowed to create databases? (y/n) y
    Shall the new role be allowed to create more new roles? (y/n) n

(13) Create a he-said-she-said Gemset:

    rvm gemset create he-said-she-said
    rvm gemset use he-said-she-said

(14) Install all Gems:

    bundle install

    Note: If you get a "can't convert nil into Integer (TypeError)" while installing kgio, see the following thread:
          https://github.com/wayneeseguin/rvm/issues/1157

(15) Create and populate application databases:

    bundle exec rake db:create:all db:migrate said:populate

(16) Start all processes:

    foreman start

(17) Start Guard and Spork:

    bundle exec guard
