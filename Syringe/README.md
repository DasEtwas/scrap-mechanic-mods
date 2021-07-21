https://steamcommunity.com/sharedfiles/filedetails/?id=1771470800

USE sminject.exe AT YOUR OWN RISK

## Introduction

sminject.exe is a proxy to read/write to an allocated piece of memory of a Peer's script.
The Peer may accept input from any client whose player sits in a seat connected to the Peer through a logic connection.
This is achieved by using a "set value" packet.
It can also give output to this client, as can be retrieved using a "get value" packet (which should trigger a response
packet from sminject).

To be able to find Peers in memory, sminject needs to scan through the entire game's memory and search for a specific
byte pattern called the delimiter (as found in Script/main.lua). Every time a read or write operation is performed,
this delimiter is checked to be an exact match. If it does not match, this means that the Peer's delimiter's address changed
or it got removed from memory, causing sminject to remove the Peer from its internal list and giving an error or removal log
message. If the Peer got "moved" in memory, a rescan should suffice to find it again.

## Terminology
injector, sminject -> The "sminject.exe" program
Peer -> The mod's part in-game called "Peer" or that part's Lua script containing game-side code.

## CLI
use --help to get CLI information

## Tutorial
Let's assume we want to make a simple app that lets us turn on and off a light via a keypress.
To get started, create a new subprocess executing "sminject.exe" (preferably using Steam's game workshop item path to the executable).
Note that the game must be running before starting the application.
If you want to get additional information on how sminject receives your data over UDP, you may execute it with
the "-n" flag (<n>etwork debug).

sminject listens for new udp packets on the specified or default (25752) port and decodes them according to the below specs.
To scan for the Peers in game memory, send a "scan" packet. sminject will block until it has completed its search of 4GB of
Scrap Mechanic's memory and remember any found Peers internally.

It is highly recommended to send "poll" packets every time that a Peer's channel could have been changed (preferably every
game frame). The "poll" instruction causes sminject to read every Peer's memory and update its internal representation inside
of sminject accordingly. It can be used frequently (~40hz). If this representation does not match the game's part (i.e. the
channel has been changed by a user), the "get"- and "set value" instructions won't be able to find, for example, the Peer's
with specific channels. (Essentially "poll" means "update" in this case).

Now that Peers have been found and their internal states are being updated, ideally periodically, you may send
"set values" packets to set the inputs of all Peers which are set to a specific channel with any value below or equal to 0.5
to turn the connected light off, or above 0.5 to turn it on.

## Networking
### sminject protocol (udp)

* byte order: big endian
* <> = parameter name
* [] = optional parameter

receives: `<packet type byte>[<data>]`


### 0x01 - Set values
'data' should contain a densely packed vector containing a 32 bit unsigned integer
and 64 bit float where those two in combination correspond to one channel to be set: the channel number
and its desired value.
			
#### Examples
```
|CB|  |      channel       |  |                  value                     |
0x01, 0x00, 0x00, 0x00, 0x04, 0x40, 0x45, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ...
```
Sets channel 4 to value 42.0
```
|CB|  |      channel       |  |                  value                     |  |      channel       |  |                  value                     |
0x01, 0x00, 0x00, 0x00, 0x08, 0x40, 0xAB, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x11, 0xBF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ...
```
Sets channel 8 to value 3546.0 and channel 17 to value -1.0


### 0x02 - Get values
'data' should contain a densely packed vector containing 32 bit unsigned integers
which represent the channels of the peer whose values you want to get. This triggers a memory read of
the game's memory to retrieve the requested values.
			
#### Examples
```
|CB|  |      channel       |  |      channel       |
0x02, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x03 ...
```
Requests the values for the first found peer for channel 4, and 3 each
			
This will return one "return values" packet per sent "get value" packet, containing the channel's index 
and value, formatted in the same format as the "set values" packet expects, except that the leading byte
is 0x0A. If the request contains channels that have no actively outputting peers, the respone will just
omit those channels.
			
a legitimate response for the first example would be:
```
0x0A, 0x00, 0x00, 0x00, 0x04, 0x40, 0x45, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
```
Which means channel 4 has a value 42.0
		
### 0x03 - Scan
Instructs the application to search for new peers. known peer's addresses will be skipped while searching. Only after aborting or finishing are new peers added to the list after receiving the next packet.

### 0x04 - Poll
Instructs the application to read each known peer and read it's memory as to update the app's internal representation of the peer.

### 0x05 - Poll
Cancels the currently running scan.
			
## Disclaimer
This application strives to be safe as it checks the delimiter of a Peer before writing, but due to the random nature of the game's garbage collection in Lua, latencies introduced by WinAPI, the time between making the check and writing memory, etc. there is a very small chance of crashing the game by literally writing into addresses at the wrong time. When this happens, you may roll a dice to tell you what will happen. Always have backups.

## Credits
* UI Base code (MPL-2.0): https://github.com/Sheggies/Sm-Keyboard/