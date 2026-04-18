# Lightroom Keyword Editor Plugin

## Overview, Motivation
_Lightroom's_ keyword editor in the _KeywordTags_ box is fine for a minimal keyword set, however it gets very unweildy if you have a large number of keywords.

I use the keywords to embed data and directives that other software uses to organize and present the images.  For me, this makes the image the single source of truth, rather than having to create another database or other structure (increasing the likelihood of getting out of sync.)

### Built in Editor

In the built in editor, the font is very small and it's easy to make selection mistakes.  That the keywords are all run-on into a single string make it hard to pick out a given keyword from the many listed.  Selecting a single keyword for removal is susceptible to errors.  Duplications are possible, as well, which further complicates ensuring the keywords are correct.

It's also possible to mis-type a keyword, inadvertently creating a new keyword that you didn't want.  _Lightroom_ happily adds the new keyword without verification.  This clutters up the keyword space, propagates errors to other software without your knowing, and makes for further effort to correct.

## Plugin Approach

This plugin presents keywords in a form that:

- Lists the keywords individually in a list.
- Adding a keyword is done in a separate entry field.
  - A suggestion grid is dynamically filled as you type, listing matching keywords as you go, similar to _Lightroom's_ built-in behavior.
- Any new keywords entered are verified before creating.
- Removing a keyword is invoked on an entry by clicking a (delete) button in the keyword row.
  - The keyword is removed from the selected images, not deleted

### Selection

The plugin works on the set of currently selected photos in the _Librayry/Grid_ view.  It will not work in any other view.

The keywords existing in the selection are listed.  Each keyword row is preceded by a count - this is the total number of images that contain this keyword. (A little bit expanded presentation than _Lightroom's_ '*' designation, although it can take longer to calculate.  If it gets onerous, I may implement a presentation similar to _Lightroom's_)

### Recently Used Grid

The plugin presents a _Recently Used_ grid for quick selection and addition to the list, paralleling _LightRoom's_ functionality, however it doesn't use _LightRoom's_ recently used list: that's not available in the SDK, so I can't get to it.

The approach here is to populate the grid with the most recently used keywords used in the dialog, itself.

Typically, you use this list to click between two or three keywords that you use frequently in a given session.  So, this behavior should be relatively adequate.

### Platform/Installation

I'm working on _MacOS_.  I haven't tried on _Windows_.  If there's interest to make it work on _Windows_, I can address that.

To install:

- Move this folder to someplace it won't get moved or deleted (optionally, just move the _KeywordEditor.lrplugin_ folder.)
- Open menu _File/Plug-in Manager/_ and the _Add_ button.
- In the _Open_ dialog, navigate to the _KeywordEditor.lrplugin_ folder contained in this folder
- Click the _Add Plug-in_ button.
