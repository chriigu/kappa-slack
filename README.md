# Kappa Slack
Add Kappa to your Slack.

## Installation

Setup your local copy by running:

```sh
git clone git@github.com:chriigu/kappa-slack.git
cd kappa-slack
bundle install
```

## Usage

Example `.env` file:

```sh
SLACK_TEAM_NAME=kappa
SLACK_EMAIL=kappa@twitch.tv
SLACK_PASSWORD=password123
```

If you have the `.env` file setup correctly, you can just run `bin/kappa-slack` to start uploading emotes.
Without an `.env` file, you can still run the script, but you need to provide options as follows:

```sh
bin/kappa-slack --slack-team-name=kappa --slack-email=kappa@twitch.tv --slack-password=password123
```

Optionally, you can pass these options to skip certain emotes:

* `--skip-bttv-emotes` (default: `false`) Skips emotes from BetterTTV
* `--skip-one-letter-emotes` (default: `true`) Skips single letter emotes, like `D:`
* `--subscriber-emotes-from-channel` Pass a channel name to download emotes only from this channel

Enjoy!
