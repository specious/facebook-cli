# Facebook CLI

Facebook command line interface

## Demo

<a href="https://asciinema.org/a/87129"><img src="https://asciinema.org/a/87129.png" width="400"/></a>

## Install

```
gem install facebook-cli
```

Requires Ruby 2.3 or later.

## Facebook configuration

The following steps are necessary to use the Facebook API:

- Create a new application at: https://developers.facebook.com/apps
- In the "Settings" tab, set "Site URL" to `http://localhost` and then add `localhost` to the "App Domains"
- Save the App ID and App Secret by running: `facebook-cli config --appid=<app-id> --appsecret=<app-secret>`

## Run

```
facebook-cli login
facebook-cli likes
```

## Commands

Running ```facebook-cli help``` shows the list of available commands:

```
COMMANDS
    config     - Save Facebook application ID and secret
    event      - Show event details
    events     - List your upcoming events
    feed       - List the posts on your profile
    friends    - List the people you are friends with (some limitations)
    help       - Shows a list of commands or help for one command
    likes      - List the pages you have 'Liked'
    login      - Log into Facebook and receive an access token
    me         - Show your name and profile ID
    pastevents - List your past events
    photos     - List photos you have uploaded
    photosof   - List photos you are tagged in
    post       - Post a message or image to your timeline
    postlink   - Post a link to your timeline
    videos     - List videos you have uploaded
    videosof   - List videos you are tagged in
```

Running ```facebook-cli help <command>``` may reveal more details.

## Converting output to HTML

The output can easily be converted to an HTML document using a Markdown renderer.  For example, with [Pandoc](http://pandoc.org/):

```
facebook-cli likes | pandoc -s -f markdown_github > likes.html
```

## Why can't I...?

Facebook has removed a large portion of their Graph API starting with version 2.0. [Niraj Shah](https://github.com/niraj-shah) has done a fantastic job documenting the cutbacks and their implications in these blog posts:

* [Facebook API: Graph API v2.4 Released, Removes Groups, Notifications and Stream Permissions](https://www.webniraj.com/2015/07/14/facebook-api-graph-api-v2-4-released-removes-groups-notifications-and-stream-permissions/)
* [Facebook Announces Graph API v2.3, More Deprecations](https://www.webniraj.com/2015/03/26/facebook-announces-graph-api-v2-3-more-deprecations/)
* [Facebook API: Getting Friends Using Graph API 2.0 and PHP SDK 4.0.x](https://www.webniraj.com/2014/06/12/facebook-api-getting-friends-using-graph-api-2-0-and-php-sdk-4-0-x/)

With so much functionality removed, it's not possible to build a full-featured interface to Facebook using the API.

If you can get a feature to work, open a pull request.

## License

MIT