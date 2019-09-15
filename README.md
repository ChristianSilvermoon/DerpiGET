# DerpiGET

A feature-rich [Derpibooru](http://derpibooru.org/) post downloader written in BASH. Tool of Mass Equine Acquisition.

REMEMBER, not all artists want their work reposted. Please DerpiGET Responsibly & Respectfully.

## How do I use this?
Well, first a good thing to keep in mind is that this was written in BASH on Linux. You might find yourself having a very difficult time using this if you're trying it on a different platform!

To begin, download or clone the repository, all you really need is the `derpiget.sh` file itself. From there, pop open a terminal, make sure it's marked as executable, hand give it a shot! `./derpiget.sh --help`

For lots of juicy details, continue reading the README!

## Features & Functionality
DerpiGET is designed to be pretty simple to use, for a full list of arguments you should try out `--help`, but here are some examples

DerpiGET's default functionality is to *download* any links/IDs piped in or used arguments to the script.

You can download them with, or without saving the meta data to a `JSON` file. Or you can just save the `JSON` file

You can tell it not to save anything, and/or to print the meta information to stdout instead, this will allow you to just view a post's Meta Data.

You can have it run silently

You can change the target domain from `derpibooru.org` to another of your choosing

You can tell it whether it should use `HTTP` instead of `HTTPS`

You can even have it return a list of search results in the form of links... and you can pipe those results into the same script again and have it download ALL OF THEM... or do whatever else you like with the results.


## Questions & Answers
Got questions? This section might answer some.

| Q: What happened to the original version? |
| --- |
| It sucked, so I re-wrote it from scratch |


| Q: Why Would you Makes This? |
| --- |
| A: I really like MLP, and [Derpibooru](http://derpibooru.org) is an amazing image board... You can never have too much pony! |

| Q: Does this use [Derpibooru's API](https://derpibooru.org/pages/api)? |
| --- |
| A: Yes, it does! That's what's up with the `jq` requirement. |

| Q: Will this work on Windows? |
| --- |
| A: Not Without a *lot* of extra stuff and work; not under normal circumstances. It may function without modification within Windows 10's [Windows Subsystem For Linux or WSL](https://msdn.microsoft.com/en-us/commandline/wsl/install_guide). |

| Q: Does this work in [Termux](https://github.com/termux/termux-app)? |
| --- |
| A: It *might*, but if not, it would likely be trivial to get it to do so. |

| Q: Will you port this to (Insert OS Name Here) |
| --- |
| A: Probably not. |
