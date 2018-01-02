# FGL form editor written in Genero BDL

## Description

This tool is a .per form editor/previewer written in Genero BDL, to achieve
WYSIWYG feeling for the edited forms.

Email comments/suggestions/wishes to : l s a t 4 j s d o t c o m

![Genero FGL Form Editor (GDC)](https://github.com/FourjsGenero/tool_fglped/raw/master/docs/fglped-screen-001.png)


## Prerequisites

* Genero BDL 2.40+
* Genero Desktop Client 2.40+
* GBC 1.41+
* GNU Make
* optional : Genero Studio 3.10+

## Compilation from command line

1. make clean all

## Compilation in Genero Studio

1. Load the fglped.4pw project
2. Build the project

## Usage

### Features

- updates after 1 second in an idle action or upon pressing F5
- has a wizard to generate forms from a schema file
- offers autocompletion when pressing 'Tab' inside the editor
- uses a special command line for "fglform" to highlight the element the cursor is over
- click to an element in the displayed form and the editor jumps to the right place in the LAYOUT section
- Uses multiple dialogs in file dialog, wizard dialog
- highlights the .per syntax with a special gdc style
- can browse/edit all forms in a directory of choice


### Installation

Make sure that the FGLPEDPATH environment variable defines the actual directory
fglped is located in.

### Usage hints

- fglped                - opens an empty form
- fglped <formname>     - opens an already existing form, or if the filename is not yet existing, tries to create a new form with the given name.
- fglped -browse        - browses all forms of the current directory
- fglped -browse <dir>  - browses all forms of given directory



### Form Display, Showing Errors

fglped has 2 windows, the active window is always the window containing the .per
source code, the other one is always inactive and shows the rendered form.

GDC:
The form display refreshes each second after the last key was pressed.
(In an ON IDLE 1 action).


If the current form is not compilable, an error line containing the first form
compiler error is displayed in the statusbar. Pressing F5 results then in showing
up a message box containing the error and jumps to the error location after
closing the messagebox.

To jump just to the position of the first error without showing a box, press F6.

If no error message is shown in the statusbar, the form was compiled and should
show up in the 2nd window. 

GBC:
It's not possible to have the editor and preview visible at the same time:
Pressing F5 previews the form if it is possible to compile.


### GDC: Synchronizing the location in the source code with the actual widget position

This only works if the form is compilable, that means pressing F5 must not
produce errors.

source code->real form:

Move the cursor inside the source code window over an element, press F5 or wait
for one second and fglped will try to highlight the corresponding widget(s) .

real form->source code:

click inside the inactive form window to a widget and fglped highlights the
clicked widget and jumps immediately with the cursor to the source code location
of the symbol referring to the widget in the LAYOUT section of the .per . 

Press Ctrl-w to jump to the next occurence of the symbol in the source code.


### Using source code autocompletion

fglform since version 2.10 has a nice code completion option ( -L <line>,<column>)
and fglped makes use of that.

You get a completion everywhere in the source code except inside the LAYOUT section,
just press the 'Tab' key and you get a list of possible symbols to choose from.

If nothing happens when you press 'Tab' then there is no completion, or the
compilation fails before the place where the cursor is located.

The source code can be incomplete AFTER or directly under the cursor but not before.
Press F6 in case you are not sure to jump to the first error location.

As an exercise, choose File->New and press then 'Tab' in the empty form.

Choose LAYOUT, and press again 'Tab' a.s.o.

For the moment the 'Tab' key is hard wired to call the completion. You must change
the Action defaults in fglped.per if this is not acceptable for you.

The limitation that there is no completion inside the LAYOUT section comes from the
fact that the LAYOUT section has no real bison grammar behind, instead it is "hand
parsed". May be in future versions of fglform this will be enhanced.

### Using the wizard to create a form from a schema file

1. Follow the instructions after choosing  File->New from Wizard which will result in a new form titled "Unnamed" on success.
2. fglped sets the path of the temporary form file to the directory containing the schema file. When saving the form in another directory than the one containing the schema upon calling File->Save make sure your DBPATH is pointing to that directory , otherwise the next recompile of the form via F5 will result in an error because the schema is not readable.

### Searching/Replacing text

Because 4GL has at the moment no way to have 2 windows active at the same time,
it is not possible to write a non modal search replace dialog like in "notepad"
(Windows). That's why Ctrl-f opens a modal search box and F3 is the hot key for
"Search again". Even more unusual is "Replace": it only replaces the first
occurence of a search string.  Press F3 to search again and F4 to replace again.
May be a check box is added in the replace dialog, to replace all occurences in
one rush. Press Shift-F4 to undo the last replace. (Note that Ctrl-Z will not
work in that case).

### Browsing all forms of a directory

Press Ctrl-b to enter the browse mode or call fglped with

```
% fglped -browse
```

This opens up the first form in the directory (as found by ls \*.per) and you
are able to step thru the list of forms by hitting:
'N' - Next Form
'P' - Previous Form
Editing a form of interest in fglped is just hitting 'E', choosing a new browse
directory hitting 'C'. Exit the browse mode via 'Esc'

## Bug fixes:
