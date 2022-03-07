# The Puzzle Cell Server Handling System

This is the repository for the official server runtime

# How to setup?

You can install the Dart SDK, download the source code and run it if you want the latest and greatest, or simply download the executables on the stable releases.

# How to run server?

You can run a server by running the executable or the source code, but you can also use some flags and options to customize the server. You can use the `--ip=<ip>` flag, in this case `<ip>` can be your IP or `self`, `local` and `zero`. `self` will translate to your public IP obtained using Ipify. `local` will translate to `127.0.0.1`, and if you know any networking, you will know that `127.0.0.1` means your local computer only. `zero` is `0.0.0.0` and is for LAN, meaning the computers in the network have to be physicall connected using Ethernet.

# Does this server automatically open ports?

No, it doesn't. You still have to open it and manage your firewall.
