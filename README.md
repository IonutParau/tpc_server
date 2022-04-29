<img 
  align="left"
  width="100"
  height="100"
  src="https://picsum.photos/100/100"
>

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

`--type` flag:

Either `sandbox` or `level`, if not set then is asked in console.

`--width` and `--height` flag:

Sets size of level in `sandbox` mode, if not set then is asked in console.

`--no-kick-allowed` flag:

`--versions` flag:

Set this to the versions you want to allow seperated by `:`. Defaults to nothing, meaning all versions are allowed.

`--whitelist` flag:

Set this to the whitelisted IDs you want to allow seperated by `:`. Defaults to nothing, meaning all IDs are allowed.

`--blacklist` flag:

Set this to the blacklisted IDs you want to allow seperated by `:`. Defaults to nothing, meaning all IDs are allowed.

`--block_uuid` flag:

Will block all IDs it thinks are UUIDs. This can be done to block people who are new to the game since they likely won't know how to change the consistent user ID. Defaults to false.

`--log` flag:

Will show in the console all packets coming from users. Defaults to false.

`--no-packetpass` flag:

Will prevent the server from sending unknown packets to all users. This can break compatibility with some mods.

`--banned_packets` flag:
The banned packets that will make the sender get kicked seoerated by `:`. This can be done to block specific functionality

`--wait_time` flag:
This can be how many milliseconds the timeout for not sending a `token` packet will be.

# Does this server automatically open ports?

No, it doesn't. You still have to open it and manage your firewall.

# Any other special configurations?

You can create a `whitelist.txt` file to put in each line allowed IDs,
You can create a `blacklist.txt` file to put in each line blocked IDs.
You can also create a `versions.txt` file for versions to allow
