# Facebook CLI

Facebook functionality from the command line.

## Demo

<a href="https://asciinema.org/a/87129"><img src="https://asciinema.org/a/87129.png" width="400"/></a>

## Install

`gem install facebook-cli` *(might require sudo)*

## Facebook setup

To interact with the Facebook API you must create and configure a Facebook application for your personal use.

- Go to https://developers.facebook.com/apps and click "Add a New App"
- Go to the "Settings" tab
  - Click "Add Platform"
  - Select "Website"
  - Set "Site URL" to `http://localhost`
  - Add `localhost` to the "App Domains"
  - Click "Save Changes"
- Go to the "App Review" tab
  - Flip the switch that says "Your app is in **development** and unavailable to the public."
  - Click "Confirm" to make your app live ([why?](# "This is required for any content you publish through this app to be visible to other users."))
- Go to the "Dashboard" tab
  - Under "App Secret" click "Show" to reveal your app secret
  - Open a terminal and save your App ID and App Secret by running:<br>

    ```
    facebook-cli config --appid=<app-id> --appsecret=<app-secret>
    ```

See: [detailed instructions with screenshots](doc/configuration.md)

## Logging in

Once the [Facebook app is configured](#facebook-setup), you must authorize it to access the social graph as you.

- In a terminal, run: `facebook-cli login`
- Open the given URL in a web browser, and log into your Facebook account if prompted
- Click "Continue" to approve the permissions
- Select the scope of your audience for any posts you publish using this application ([read more](https://www.facebook.com/help/211513702214269))
- Click "Ok" to continue
- Close the browser tab

See: [detailed instructions with screenshots](doc/configuration.md#logging-in)

## Run

```
facebook-cli login
facebook-cli likes
```

## Commands

Running ```facebook-cli help``` shows the list of available commands:

```
COMMANDS
    api        - Make a Facebook API request
    config     - Save Facebook application ID and secret
    event      - Show event details
    events     - List your upcoming events
    feed       - List the posts on your profile
    friends    - List the people you are friends with (some limitations)
    help       - Shows a list of commands or help for one command
    likes      - List the pages you have 'Liked'
    links      - Some useful URLs
    login      - Log into Facebook and receive an access token
    logout     - Deauthorize your access token
    me         - Show your profile information
    pastevents - List your past events
    photos     - List photos you have uploaded
    photosof   - List photos you are tagged in
    post       - Post a message or image to your timeline
    postlink   - Post a link to your timeline
    postvideo  - Post a video to your timeline
    videos     - List videos you have uploaded
    videosof   - List videos you are tagged in
```

Run ```facebook-cli help <command>``` for more details on each command.

## Converting output to HTML

Use a Markdown renderer to easily convert the output to an HTML document.  For example, using [Pandoc](http://pandoc.org):

```
facebook-cli likes | pandoc -s -f markdown_github > likes.html
```

## Why can't I...?

Facebook has removed a large portion of their Graph API starting with version 2.0. [Niraj Shah](https://github.com/niraj-shah) has done a fantastic job documenting the cutbacks and their implications in these blog posts:

* [Facebook API: Graph API v2.4 Released, Removes Groups, Notifications and Stream Permissions](https://www.webniraj.com/2015/07/14/facebook-api-graph-api-v2-4-released-removes-groups-notifications-and-stream-permissions/)
* [Facebook Announces Graph API v2.3, More Deprecations](https://www.webniraj.com/2015/03/26/facebook-announces-graph-api-v2-3-more-deprecations/)
* [Facebook API: Getting Friends Using Graph API 2.0 and PHP SDK 4.0.x](https://www.webniraj.com/2014/06/12/facebook-api-getting-friends-using-graph-api-2-0-and-php-sdk-4-0-x/)

An [article](https://developers.facebook.com/blog/post/2012/10/10/growing-quality-apps-with-open-graph/) published in October, 2012 by Facebook developer [Henry Zhang](https://www.facebook.com/hzz) provides insight into the reasoning:

> Post to friends wall via the API generate a high levels of negative user feedback, including “Hides” and “Mark as Spam" and so we are removing it from the API. If you want to allow people to post to their friend’s timeline from your app, you can invoke the feed dialog.

The functionality removed renders it impossible to build a full-featured interface to Facebook through the Graph API alone.

If you expand the functionality, please [open a pull request](https://github.com/specious/facebook-cli/pulls).

## Development

Clone this repository, then install Ruby dependencies with [Bundler](http://bundler.io):

```
gem install bundler
bundle install
```

You should now be able to run *facebook-cli* from the `bin` directory:

```
bin/facebook-cli
```

*facebook-cli* depends on the [Koala](https://github.com/arsduo/koala) library for interfacing with Facebook's Graph API and [GLI](https://github.com/davetron5000/gli) for parsing command line arguments.

Using a ruby environment manager such as [rbenv](https://github.com/rbenv/rbenv) or [rvm](https://rvm.io) is advisable to avoid environment conflicts between projects.

Please read the guide on [how to contribute](CONTRIBUTING.md).

## Other applications

- [fb-messenger-cli](https://github.com/Alex-Rose/fb-messenger-cli)
- [Messenger for Desktop](https://github.com/Aluxian/Messenger-for-Desktop)

## License

ISC
