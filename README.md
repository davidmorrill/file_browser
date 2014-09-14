File Browser Web App
--------------------

This is a simple app I wrote to get some experience writing web apps using Dart.
As such it may be of limited or no use to anyone else, but I am making it
available as an example for others to study or use as desired.

The app allows a user to browse text files contained in one or more directory
hierarchies. One of the reasons I wrote this app is that I wanted to be able to
browse source code from a tablet as well as a laptop or desktop.

The app is divided into two parts:

- **bin/**:
  A web server that serves the static files needed to load the web app and also
  supports a RESTful API used by the web app to display text files contained in
  a configurable set of directory hierarchies.

- **web/**:
  A web app that allows a browser user to navigate to and display text files
  located in the file system directory hierarchies exposed by the web server's
  REST API.

Some annotated screen shots of the web app running under Dartium are shown
below:

![File Browser 1](https://cloud.githubusercontent.com/assets/213759/4261801/da0a45ae-3b7e-11e4-9a3b-3c2026c8d10f.png)

![File Browser 2](https://cloud.githubusercontent.com/assets/213759/4261799/da07df4e-3b7e-11e4-9394-2bcebb3a400a.png)

![File Browser 3](https://cloud.githubusercontent.com/assets/213759/4261800/da0a379e-3b7e-11e4-881d-3494c85ab9eb.png)

![File Browser 4](https://cloud.githubusercontent.com/assets/213759/4261798/da063496-3b7e-11e4-8df3-1fd71e0e21c0.png)

![File Browser 5](https://cloud.githubusercontent.com/assets/213759/4261802/da0c2c2a-3b7e-11e4-9a88-30b1b11b8469.png)

The app view is divided into three sections:

- **Directory selector** (top-left):
      The directory selector shows directories from the part of the file system
      exposed by the web server. The top-most entry (i.e. '/') represents the
      root of the exposed file system. Initially this entry is selected, as
      indicated by the color highlighting, and all of its subdirectories are
      displayed below it. Clicking on a subdirectory highlights the
      subdirectory, removes its siblings from the list, and adds the selected
      subdirectory's child subdirectories below it in the list.

      The entries in the list form a kind of vertical stack. One entry is always
      selected and highlighted. The entries above the selected directory are its
      parent directories. All of the entries below the selected directory are
      its child subdirectories. Clicking any entry in the list selects it and
      adjusts the stack accordingly.

      The intent of this approach is to provide a visually compact view of the
      file system hierarchy as well as make it fairly simple to navigate around
      the hierarchy.

- **File selector** (bottom-left):
      Whenever a directory is selected in the directory selector, all of the
      recognized text files contained in the directory are displayed in the file
      selector located below the directory selector. Note that the types of
      files displayed can be configured in the web server.

      Selecting any file in the list highlights it and displays its contents in
      a new tab within the file contents viewer to its right.

- **File contents viewer** (right-half):
      The file contents viewer located in the right half of the app view simply
      displays the contents of previously selected text files, with line numbers
      shown on the left. Each selected file is displayed under its own tab.
      Selecting a tab brings its contents to the front of the stack of open
      files. Clicking the close icon in a tab removes the file and tab from the
      viewer.

      Located just below the set of open tabs is an information line that shows
      information about the currently selected tab's contents. On the left hand
      side of thr information line are filter and search icons. Clicking them
      opens or closes the corresponding file filter and text content search
      toolbars, which allow you to specify search criteria and display options.
      You can also open these toolbars by hovering the mouse pointer over the
      toolbar tabs located along the left edge of the window.

Configuring the server
----------------------

The web server can be configured by modifying the *bin/file_server.json* file,
which is a JSON formatted text file containing various server parameters. The
default contents of the file are:

    {
      "host": "127.0.0.1",
      "port": 8090,
      "expiration": 10,
      "types": [
        ".bat", ".c", ".coffee", ".cpp", ".css", ".dart", ".h", ".hpp", ".htm",
        ".html", ".java", ".js", ".json", ".less", ".md", ".py", ".rb", ".sass",
        ".scss", ".styl", ".txt", ".xml", ".yaml"
      ],
      "roots": [
        ".."
      ]
    }

where:

- **host**: The host name or IP address to use.
- **port**: The TCP port to use.
- **expiration**: How long, in minutes, content search results are cached.
- **types**: The list of text file extensions to serve.
- **roots**: The list of root directories to serve. More than one directory can
  be specified. If multiple root directories are specified, they appear under
  the top '/' entry in the directory selector. If only a single root directory
  is specified, the top '/' entry corresponds to that directory.

Running the server
------------------

The server is started by running the *bin/file_server.dart* file:

    dart file_server.dart [directory, ..., directory]

The command accepts an optional list of directory paths which, if specified,
override the root directories specified in the *bin/file_server.json*
configuration file.

Launching the file browser app
------------------------------

The browser app is started by entering the following URL into your web browser:

    http://host:port/file_browser.html

If you are not using the *Dartium* browser, please use the Dart IDE to
generate the Javascript file for the app.

Notes:
------

- The visual appearance of the browser app is defined by
  *web/file_browser.styl*, which is a *Stylus*-based set of CSS rules. The
  actual generated *web/file_browser.css* file used by the app is included in
  the source code in case you don't have Stylus installed.

- Many of the visual characteristics of the app are defined by commented
  constants defined at the top of *web/file_browser.styl*. So if you have Stylus
  installed, you should be able to tweak the appearance of the app simply by
  editing these values and regenerating the corresponding CSS file.
