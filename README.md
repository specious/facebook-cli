# Facebook CLI

Facebook command line interface

## Install

```
gem install facebook-cli
```

Requires Ruby 2.3 or later.

## Facebook configuration

The following steps are necessary to use the Facebook API:

- Create a new application at: https://developers.facebook.com/apps
- In the Settings tab, add `localhost` to the App Domains
- Save the App ID and App Secret by running: `facebook-cli config --appid=<app-id> --appsecret=<app-secret>`

## Run

```
facebook-cli login
facebook-cli likes
```

## Commands

Run:

```
facebook-cli help
```

## Converting output to HTML

The output can easily be converted to an HTML document using a Markdown renderer.  For example, with [Pandoc](http://pandoc.org/):

```
facebook-cli likes | pandoc -s -f markdown_github > likes.html
```

## License

MIT