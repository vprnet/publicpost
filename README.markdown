Note: These instructions apply to a fresh install on OS X 10.8.2.
Note: Heroku is the expected production environment.

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

(12) Configure environment variables
    The application relies on a number of environment variables. Those can be found in config/environments/heroku-environment-variables.txt there are also other locations in the code base that should be customized for your deployment. You can search the code base for "FILL_ME_IN" to find those. Good candidates for environment variables.

(13) Create a DB user for the application:

    createuser --interactive he-said-she-said
    Shall the new role be a superuser? (y/n) n
    Shall the new role be allowed to create databases? (y/n) y
    Shall the new role be allowed to create more new roles? (y/n) n

(14) Create a he-said-she-said Gemset:

    rvm gemset create he-said-she-said
    rvm gemset use he-said-she-said

(15) Install all Gems:

    bundle install

    Note: If you get a "can't convert nil into Integer (TypeError)" while installing kgio, see the following thread:
          https://github.com/wayneeseguin/rvm/issues/1157

(16) Create and populate application databases:

    bundle exec rake db:create:all db:migrate said:populate

(17) Start all processes:

    foreman start

(18) Start Guard and Spork:

    bundle exec guard

# Overview
Currently crawls all known municipal websites in Vermont and a handful in other cities in the United States. The system as currently implemented is capable of handling the workload for all of Vermont, additional municipalities could be brought online by increasing the number of workers and scaling of resources. Increasing the number of municipalities by to more than 1,000 is not advisable.

# Environment variables
Any value that was hard coded have been replaced in code with 'FILL_ME_IN'. Relevant Heroku environment variables can be found in config/heroku-environment-variables.txt

# What is happening?
* We have a list of municipality URLs
* We crawl them each day, looking for new documents
* When we find a new document we analyze it and store the results

# How it starts
* *rake said:crawl_municipalities* - This rake task is called each day, triggering the start of a crawl. It retrieves each municipality from the database and starts the workflow for it.

* *rake said:send_search_alerts* - This triggers the sending of email search alerts each day that users have stored in the database. 

# Heroku setup
## Dynos
* web bundle exec unicorn -p $PORT -c ./config/unicorn.rb
* worker bundle exec sidekiq -v -c 3 -q high,4 -q medium,3 -q low,2 -q default,1

## Add-ons
* Heroku Postgres Crane - database
* Heroku Scheduler - to run rake tasks daily
* Mailgun - for sending emails
* New Relic - for monitoring
* PG Backups - for database backups
* Redis To Go Mini - for Sidkiq messages
* Zerigo DNS Basic - for DNS

# Municipality Processing Workflow
View the Workflow class. This coordinates how municipality websites are crawled and what happens to a document when we find one. We use Sidekiq messaging and workers to asynchronously process the jobs. The messages are stored in Redis. The core jobs in the workflow are:

1. start_crawl_municipality
2. start_process_document
3. start_extract_text
4. start_extract_meaning
5. start_analyze_document

Jobs have different priorities. Document processing jobs take priority over crawling jobs. The thinking here is that it is more important to know the output of the currently collected documents rather than to keep collecting them.

# Crawling
We use a forked version of Anemone: https://github.com/NearbyFYI/anemone. Generally municipal websites are terrible. They have difficulty handling concurrent requests, have robots.txt files that limit access, publish documents as PDFs or other non-HTML formats and have calendar and event software that makes it easy for a web crawler to enter into crawl hole. The work that went into our forked version of Anemone was to address many of these things.

The crawler is quite stable though, and we use the output of *rake said:website_health_report* to identify websites that are returning 404 or have encountered some other issue. Occasionally a municipality changes the URL without putting proper redirection in place.

Another challenge is that sometimes municipal websites are mis-configured for content type disposition. Often representing a PDF as text-html. There are a lot of little modifications that are quite specific to what we've learned about crawling city and town websites.

As a document from a municipality is found by the crawler we move it through the *Workflow.rb*. Often Municipalities will move a document, publishing it to a location and then moving it without putting in an HTTP redirect of any sort. This can result in duplicate documents being collected, also, we rely on the HTTP Last-Modified date to determine if a document has been modified and should be collected again, MOST cities and their CMS's do a poor job of actually updating the last modified date for non-HTML based documents. This can result in a document being collected and then subsequently changed, yet our collection methods would not pick up the change. Ideally we'd retrieve each document during every crawl and perform a diff to determine if the document has actually been updated.

Review the Constants module in environment.rb to see the website specific customizations to the skip_links.

# Document Processing
## Extraction & Analysis
Many of the documents that are published by municipalities are non-html. The extraction and analysis portion of the pipeline can be time consuming and resource intensive. To keep costs low and to provide for better scaling we've moved the extraction and analysis services out to separate Heroku instances that are called via HTTP.

* *text-extractor* - https://github.com/NearbyFYI/text-extractor is a Sinatra wrapper around the Yomu gem. Given a URL it will attempt to provide you with the text from that document. We deployed several (5) of these to free Heroku instances. The NearbyFYI workflow is aware of the 5 instances and uses one randomly during the processing phase. Each Heroku instance has 3 Unicorn worker processes, so we can get a fair number of extractors for free, while offloading the memory usage to another server.

* *text-entities* - https://github.com/NearbyFYI/text-entities web service for interacting with the Stanford NER web application. Given text it will return entities it detects. The could be replaced by a service like Open Calais or AlchemyAPI. We didn't want to pay for those services, or give them the documents that we've collected. Ideally, an extraction model is trained specifically for municipal government. That would improve the extraction.

* *Classification* - The methods to determine which type of document we've collected are, rudimentary, use brute force and are often wrong. This is an area where humans could greatly benefit the process. There was a start to use https://github.com/alexandru/stuff-classifier but it needs to be trained. I was getting decent results from the classification.

* *date extraction and identification* - This is a source of much pain. Whoever takes this on, please forgive me for the date detection logic in Document.find_likely_dates. After much tweaking, this gets dates correct about 80-90% of the time from the documents that we have collected and reviewed by hand. If there is a process for manually reviewing each document, this can all go away.

* *Terms*
We use the Stanford Core NLP Ruby gem to extract terms from the text. We use a similar strategy as the text extraction, spinning up several free Heroku instances that have a Sinatra wrapper to the gem, allowing us to call the service over HTTP and avoid memory and Heroku worker limitations.

* *determine_owning_organization* This method attempts to detect the organization that published the document. For example, the meeting minutes from the Board of Selectman or the agenda items for the Town Council. There is considerable tweaking that went into the regular expressions for this.

# Document Storage
Each document collected is stored in an Amazon S3 bucket associated with the municipality. For example: com.nearbyfyi.com.said.production.burlington-vt would contain all the documents that we've found for Burlington, Vermont. This is the raw binary that we have found. We generate a unique identifier for that document based on the URL where we collected it.

# Database
We use Postgres. We have a paid database on Heroku which costs $50/month. The Database is currently ~6GB in size with 11 tables.
 
# Search
Search is backed by ElasticSearch. It is currently deployed to a FREE Amazon EC2 micro instance. You could consider replacing the self-hosted search with a service like Found.no. The ES index is currently 1.8GB in size. Running on Found would cost about $90/month.

The documents are updated in the search index during Document.after_commit. We use the Tire gem to assist with the interactions with the ElasticSearch server.

# Alerts
Triggered via the said:send_search_alerts rake task. The job queries the database for saved searches and iterates over them, sending emails to the owner via Mailgun. ElasticSearch has better methods for doing this now through 'percolation'. Storing the queries in the database would continue to work though, unless there are several hundred or thousand stories search queries.

# Frontend
Is Rails 3.2 running on Ruby 1.9.3. There are minimal tests. Coverage is poor, something that would be useful to incorporate if the service were to grow beyond it's current use. We made a conscious choice to skip the tests, I'd still do it that way again. Likely not for another project but for this one it worked.
