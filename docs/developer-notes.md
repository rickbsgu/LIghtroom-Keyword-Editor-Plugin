# Lightroom Keyword Editor Plugin - Developer Notes

>  <div style="text-align:center; font-style: italic;padding: 1em;">Note: Although I'm an experienced software developer, I'm a newbie with Lua and the Lightroom SDK.  These notes represent my level of experience with the platform and may not necessarily represent best or optimal practices.</div>
<br/>

Frankly, the _Lightroom_ plugin development environent is a hostile environment.  You don't have access to a debugger, can't inspect variable values, errors often happen silently or present an error dialog with no usable information, or kill the plugin outright and you don't know where it happened or why.

## Run Lightroom from the Commandline

For me, the first line of action was to run the application from the commandline.  _Lightroom_ actually spews out a _bunch_ of information to stdout/stderr, but you never see it if you launch it with a click.

Most invaluably, it prints out a traceback if your plugin crashes.  That traceback provides much more accurate information than any popup error dialog.

<u>To Launch On MacOS:</u>
> cd to `/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app`  
>   
> To invoke: `./Contents/MacOS/Adobe\ Lightroom\ Classic`

<u>To Launch on Windows</u>  
(??)

I run it from an extra terminal instance in _VSCode_.

## LrDialogs.message()

The next debugging tool is good old dialog/alert implementations &mdash; the UI equivalent of print statements.  (Actually, since you're running from the commandline, you _can_ use print statements. The caveat is you have to be able to distinguish your print statements from the proliferated messages that come out during normal operations.)

## Logging

The _Lightroom_ SDK has a logging service.  Frankly, I didn't use it because I don't like fishing through the directory structure to find and read it.

This project has a logging service module _(LogService.lua)_ that prints to a file location of your choice.  It is currently disabled.  To enable it:
  - Create a folder to contain the logfile.  Make sure _Lightroom_ can read and write to it.
    - I created a folder _log_ in the project root and an empty file named _log.txt_ in that folder. This allows me to open it in VSCode and see changes as they happen.
  - Modify _LogService.lua_ to assign the local variable _logPath_ to that folder/filename you want to send the output.
  - Reload the plugin.

<u>**Important!**</u>: When you're done developing and want to deploy, change the _logPath_ assignment value to back to _nil_, so it doesn't try to write to a file that doesn't exist on a users file system.

## Table Dumps

Lua/_Lightroom SDK_ don't have native table (structure) dump facilities.  You have to provide your own (or use _Lightroom's_ logging service, which can dump tables, I believe.)

In the _LogService.lua_ module, there is a 'serialize' function.  You can use that to either append the output to the log (via the 'append' function), or output it to a messages dialog.

## Rerunning

... is a royal _PITA_.  You have to click the _File/Plugin-Manager -> Reload Plugin_ sequence every time you make a change, and then invoke the plugin from the _Library/Plugin Extras/Open GB Keyword Editor_ menu. That amounts to five clicks with lots of mouse movement for every change.

_Every time you make a change!_

If you add or remove a source file, you likely need to remove the plugin entirely and then re-add it. _Lightroom_ sometimes doesn't see the changes.  It can be worthwhile to add a temporary "build no." readout to the dialog somewhere, and update it after every change to convince yourself the plugin is getting loaded.

It gets stultifying after a while, especially if you're using an AI agent &mdash; it reduces you to a multi-click robot.

I haven't found a way to shorten the process, certainly not the first part.  For the second part, you _may_ be able to define a system-level hot-key to invoke the plugin.

_Lightroom_ itself doesn't provide a way to assign a hot-key to invoke a plugin.