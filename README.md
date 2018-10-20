# ClassicPress nightly builder

- Copy `example-config.sh` to `config.sh` and fill in the values
- `git clone https://github.com/ClassicPress/ClassicPress ClassicPress`
- `git clone https://github.com/ClassyBot/ClassicPress-nightly ClassicPress-nightly`
- Set `build-and-log.sh` to run as a cron job at midnight UTC (on a server that's using
  the UTC time zone, so that the build date is right)
