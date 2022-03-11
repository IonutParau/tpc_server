# The Puzzle Cell Server Handling System

This is the repository for the official server runtime

# How to setup?

You can install the Dart SDK, download the source code and run it if you want the latest and greatest, or simply download the executables on the stable releases.

# How to run server?

You can run a server by running the executable or the source code, but you can also use some flags and options to customize the server.

# Flags and options

`--ip` flag:

Specifies IP to be used by server, default is `--ip=local`
- `self`: will automatically get your public IP using Ipify.
- `local`: equals to `localhost` or `127.0.0.1`, means it will be only accessable by your computer and no other.
- `zero`: equlas to `0.0.0.0` and opens your server for LAN, meaning the computers in the network have to be physically connected using Ethernet or use the same WiFi network.
- any other option will tell server to run on specified IP address.


`--port` flag:

Specifies port to be used by server, default is `--port=8080`


`--silent` flag:

Will reduce amount of messages you get in console, default is `--silent=false`


`--kick-allowed` flag:

Setting this to `false` will disallow server to kick any members, default is `--kick-allowed=true`


# Does this server automatically open ports?

No, it doesn't. You still have to open it and manage your firewall.
