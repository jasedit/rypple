# Overview
A tool for integrating some remote file store (e.g. Dropbox) with a static site generator (e.g. jekyll) with some tools to ease remote updating of the site.

# Installation
The easiest method to install Rypple is to use (RubyGems)[https://rubygems.org/]. To do so, simply install RubyGems, and at the command prompt type:
    gem install rypple

For some sites, such as (NSFN)[https://www.nearlyfreespeech.net/], this should be modified to:
    RB_USER_INSTALL=true gem install rypple

## Configuration
Once installed, Rypple needs to be configured for each site being synced by it. This is done through the rypple command, and can be initiated using the command:
    rypple -s

Which kicks off the configuration process. This process will guide you through several important configuration options.
1. Rypple site directory. This is the directory to which files will be saved - by default, this is set to $HOME/ryppleSite, but can be changed to any site you wish. This is not the location which will be publicly accessible, so please do not point this at your web server.
2. Dropbox API Configuration
    1. Generate a Dropbox API key/secret pair from their website. IMPORTANT: When creating the key, there is a question about granting the API access to your entire Dropbox folder, or only a sandboxed folder. This option, as far as I can tell, is immutable - Rypple supports either, but be aware of the choice being made.
    2. Enter the API key and secret.
    3. Select the API access mode the API key/secret were configured to allow. This option must match what was specified earlier, or else the system won't be able to connect.
    3. Visit the webpage requested by the setup script to complete the configuration step.
3. (Optional) Configure the web host to use Ruby Gems.
4. Select the location for the static site generator to output files. This goes into configuring the sync portal for your site.
5. (Optional) Enable basic user authentication through a .htaccess file. This allows you to create a user/password combination for the sync portal, so bots don't spam the form to cause your site to update.
6. Wait for the first update to complete. Everything should sync and be ready to go!

