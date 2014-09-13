//------------------------------------------------------------------------------
//
//  File browser client for use with the file server (file_server.dart)
//
//  Allows users to browser the text file contents of the file system hierarchy
//  being served by the file server.
//
//  Copyright 2014 by David C. Morrill
//
//------------------------------------------------------------------------------
// FIXME: Fix tab scrollbar issue
// TODO: Support syntax highlighting for various languages
//------------------------------------------------------------------------------

//-- Imports -------------------------------------------------------------------

import 'dart:math';
import 'dart:html';
import 'dart:convert';
import "package:path/path.dart" as path;

//-- Browser main function -----------------------------------------------------

void main() {
  new FileBrowser( querySelector( '#filebrowser' ) );
}

//-- FileBrowser class ---------------------------------------------------------

class FileBrowser {

  // The element containing the file browser:
  Element container;

  // The element containing the directory list:
  Element directoryContainer;

  // The element containing the file list:
  Element fileContainer;

  // The most recently selected file element:
  Element fileItem;

  // The current list of parent directories (the last is the active directory):
  List<String> parents = [];

  // The current list of child directories of the active directory):
  List<String> children = [];

  // The current list of files in the active directory:
  List<String> files = [];

  // The path to the files currently being displayed:
  String filesPath = '';

  // The list of open file tabs:
  List<FileTab> tabs = [];

  // The currently selected tab:
  FileTab tab;

  // The list of text lines in the currently selected file:
  List<String> lines;

  // The current vertical scroll bar position:
  int scrollTop = 0;

  // The current filter string:
  String filter = '';

  // Is the filter string a regular expression?
  bool filterRegex = false;

  // Is the filter case sensitive?
  bool filterCaseSensitive = false;

  // The current search string:
  String search = '';

  // Is the search string a regular expression?
  bool regex = false;

  // Is the search case sensitive?
  bool caseSensitive = false;

  // Should the search string be applied to all files in the file list?
  bool inFiles = false;

  // Show context lines above each match?
  bool contextTop = true;

  // Show context lines below each match?
  bool contextBottom = true;

  // Is the file filter tool bar open?
  bool filterOpen = false;

  // Is the content search tool bar open?
  bool searchOpen = false;

  // Number of search context lines to display:
  int context = 1;

  // Constructs a new file browser in the DOM element specified by [container]:
  FileBrowser ( this.container ) {
    directoryContainer = new DivElement()..className = 'directories';
    fileContainer      = new DivElement()..className = 'files';
    container.children = [ directoryContainer, fileContainer ];
    querySelector( '#filter'        ).onInput.listen( _filterChanged );
    querySelector( '#filterregex'   ).onClick.listen( _filterRegexChanged );
    querySelector( '#filtercase'    ).onClick.listen( _filterCaseChanged );
    querySelector( '#search'        ).onInput.listen( _searchChanged );
    querySelector( '#regex'         ).onClick.listen( _regexChanged );
    querySelector( '#case'          ).onClick.listen( _caseChanged );
    querySelector( '#infiles'       ).onClick.listen( _infilesChanged );
    querySelector( '#context'       ).onInput.listen( _contextChanged );
    querySelector( '#contextTop'    ).onClick.listen( _contextTopChanged );
    querySelector( '#contextBottom' ).onClick.listen( _contextBottomChanged );
    querySelector( '#filteropen'    ).onClick.listen( _filterOpenChanged );
    querySelector( '#searchopen'    ).onClick.listen( _searchOpenChanged );
    _getDirectory( '', auto_select: true );
  }

  // Gets the directories and files contained in the directory specified by
  // [path]:
  void _getDirectory ( String directory,
                       { bool auto_select: false, filePath } ) {
    Map<String,String> queryParams = {};
    if ( !directory.isEmpty ) queryParams[ 'path' ] = '$directory';
    _searchEncode(
      queryParams, 'filter', filter, filterRegex, filterCaseSensitive
    );
    if ( inFiles ) {
      _searchEncode( queryParams, 'search', search, regex, caseSensitive );
    }
    String uri = new Uri( path: 'dir',
                          queryParameters: queryParams ).toString();
    HttpRequest.getString( uri ).then(
      ( String json ) {
        parents..clear()..add( '/' )..addAll( path.split( directory ) );
        children.clear();
        files.clear();
        JSON.decode( json ).forEach( ( String item ) {
          (item.startsWith( '+' )? children: files).add( item.substring( 1 ) );
        } );
        _rebuildLists();

        if ( auto_select && (fileContainer.children.length > 0) ) {
          _getFile( fileContainer.children.first );
        } else if ( filePath != null ) {
          for ( var item in fileContainer.children ) {
            if ( filePath == item.getAttribute( 'fullPath' ) ) {
              fileItem = item..classes.add( 'selected' );
              break;
            }
          }
        }
      }
    );
  }

  // Updates the list of files based on the current directory, search and
  // filter information:
  void _updateFiles ( ) {
    _getDirectory(
        filesPath.substring( 1 ),
        filePath: (fileItem == null)? null: fileItem.getAttribute( 'fullPath' )
    );
  }

  // Encodes a search or filter as a URI query parameter:
  void _searchEncode ( Map<String,String> queryParams, String name,
                       String value, bool regex, bool caseSensitive ) {
    if ( (!value.isEmpty) &&
         (!querySelector( '#$name' ).classes.contains( 'error' )) ) {
      queryParams[ name ] = "${regex?'t':'f'}${caseSensitive?'t':'f'}$value";
    }
  }

  // Rebuilds the DOM directories and files lists based on the current values of
  // the [parents], [children] and [files] lists:
  void _rebuildLists ( ) {
    List<Element> directoryDivs = [];
    String fullPath             = '';
    parents.forEach( ( directory ) {
      directoryDivs.add(
          _newDiv( directory, fullPath, 'directory', _directorySelected )
      );
      fullPath = path.join( fullPath, directory );
    } );
    directoryDivs.last.classes.add( 'selected' );
    children.forEach( ( directory ) {
      directoryDivs.add(
          _newDiv( directory, fullPath, 'child', _directorySelected )
      );
    } );
    directoryContainer.children = directoryDivs;
    filesPath = fullPath;
    fileItem  = null;
    _showFiles();
  }

  // Display the list of the filtered files in the current directory:
  void _showFiles ( ) {
    List<Element> fileDivs = [];
    files.forEach( ( file ) {
      fileDivs.add(
          _newDiv( file, filesPath, 'file', _fileSelected )
      );
    } );
    fileContainer.children = fileDivs;
  }

  // Returns a new DivElement used for populating the directories/files lists:
  DivElement _newDiv ( String text, String fullPath, String className,
                      void handler( MouseEvent e ) ) {
    var completePath = path.join( fullPath, text );
    return new DivElement()
        ..text      = text
        ..classes   = [ 'item', className ]
        ..title     = completePath
        ..onClick.listen( handler )
        ..setAttribute( 'fullPath', completePath.substring( 1 ) );
  }

  // Load the file associated with [element] into the content view:
  void _getFile ( Element element ) {
    if ( element != fileItem ) {
      if ( fileItem != null ) fileItem.classes.remove( 'selected' );
      fileItem        = element..classes.add( 'selected' );
    }
    String fullPath = element.getAttribute( 'fullPath' );
    HttpRequest.getString( '/file?path=$fullPath' ).then(
      ( String text ) {
        var aTab = _getTab( fullPath );
        if ( aTab == null ) {
          aTab = new FileTab( fullPath );
          _addTab( aTab );
        }
        aTab.lines = text.replaceAll( '\r\n', '\n' )
                         .replaceAll( 'n\r', '\n' )
                         .split( '\n' );
        _setTab( aTab );
      }
    );
  }

  // Display all text lines in the current file using the current search filter:
  void _showLines ( { animate: true } ) {
    List<Element> textLines;
    int line         = 0;
    bool error       = false;
    Element fileInfo = querySelector( '#fileinfotext' );
    if ( lines == null ) {
      textLines     = [];
      fileInfo.text = 'Click directory or file on left side to display, click '
                      'filter or search icons to toggle tool bars';
    } else if ( search.isEmpty ) {
        textLines = lines.map(
          ( content ) => _textLine( ++line, content )
        ).toList();
        fileInfo.text = "Total of ${_plural(lines.length, 'line', 's')}";
    } else {
      var searcher, searchFor;
      if ( regex ) {
        try {
          searchFor = new RegExp( search, caseSensitive: caseSensitive );
          searcher  = _regexSearch;
        } catch ( exception ) {
          error = true;
        }
      }
      if ( searcher == null ) {
         if ( caseSensitive ) {
           searchFor = search;
           searcher  = _caseSensitiveSearch;
         } else {
           searchFor = search.toLowerCase();
           searcher  = _caseInsensitiveSearch;
         }
      }
      int matchCount  = 0;
      int lineCount   = 0;
      int lastOutput  = -1;
      int remaining   = (context < 0)? 10000000: 0;
      bool startGroup = false;
      textLines       = [];
      lines.forEach( ( String text ) {
        line++;
        Iterable<Match> matches = searcher( searchFor, text );
        if ( matches.isEmpty ) {
          if ( remaining > 0 ) {
            textLines.add( _textLine( line, text ) );
            lastOutput = line;
            remaining--;
          }
        } else {
          Element textElement;
          lineCount++;
          matchCount += matches.length;
          int first = contextTop?
              max( max( lastOutput + 1, line - max( context, 0 ) ), 1 ):
              line;
          startGroup = (first == 1) || (first > (lastOutput + 1));
          for ( ; first < line; first++ ) {
            textElement = _textLine( first, lines[ first - 1 ] );
            if ( startGroup ) {
              startGroup = false;
              textElement.classes.add( 'startGroup' );
            }
            textLines.add( textElement );
          }
          textElement = _textLine( line, text, matches );
          if ( startGroup ) {
            startGroup = false;
            textElement.classes.add( 'startGroup' );
          }
          textLines.add( textElement );
          lastOutput = line;
          if ( contextBottom && (context >= 0) )
            remaining = context;
        }
      } );
      fileInfo.text =
        "Total of ${_plural(matchCount, 'match', 'es')} on "
        "${_plural(lineCount, 'line', 's')} out of "
        "${_plural( lines.length, 'line', 's')}";
      scrollTop = 0;
    }

    if ( !textLines.isEmpty ) {
      textLines.first.classes.add( 'startGroup' );
      textLines.last.classes.add( 'endGroup' );
    }

    _errorState( '#search',  error );

    var file2      = querySelector( '#file2' );
    var scrollTemp = file2.scrollTop;
    var file1      = querySelector( '#file1' )
      ..children   = file2.children
      ..scrollTop  = scrollTemp;
    file2..children  = textLines
         ..scrollTop = scrollTop;

    if ( animate ) {
      file1.classes.add( 'prescroll' );
      file2.classes.add( 'prescroll' );

      // NOTE: We need to request two animation frames since sometimes the
      // 'prescroll' class has not been rendered yet if we remove it in the
      // first animation frame, and so no animation occurs:
      window.animationFrame.then(
        ( timeStamp ) => window.animationFrame.then(
          ( timeStamp ) {
            file1.classes.remove( 'prescroll' );
            file2.classes.remove( 'prescroll' );
          }
        )
      );
    }
  }

  // Set the correct 'error' state for an input field:
  void _errorState ( String inputId, bool hasError ) {
    Element input = querySelector( inputId );
    bool hadError = input.classes.contains( 'error' );
    if ( hasError ) {
      if ( !hadError ) input.classes.add( 'error' );
    } else if ( hadError ) input.classes.remove( 'error' );
  }

  // Performs a regex search of the specified text:
  Iterable<Match> _regexSearch ( RegExp search, String text ) {
    return search.allMatches( text );
  }

  // Performs a case sensitive search of the specified text:
  Iterable<Match> _caseSensitiveSearch ( String search, String text ) {
    return search.allMatches( text );
  }

  // Performs a case insensitive search of the specified text:
  Iterable<Match> _caseInsensitiveSearch ( String search, String text ) {
    return search.allMatches( text.toLowerCase() );
  }

  Element _textLine ( int line, String text, [ Iterable<Match> matches ] ) {
    DivElement content = new DivElement()..className = 'linetext';
    DivElement result  = new DivElement()
        ..className = 'textline'
        ..children = [
          new DivElement()
              ..className = 'linenumber'
              ..text      = line.toString(),
          content
        ];

    if ( matches == null ) {
      content.text = (text.length == 0)? ' ': text;
    } else {
      List<Element> spans = [];
      int current         = 0;
      matches.forEach( ( Match match ) {
        int start = match.start;
        int end   = match.end;
        if ( start > current ) {
          spans.add(
              new SpanElement()..text = text.substring( current, start )
          );
        }
        spans.add(
            new SpanElement()..text      = text.substring( start, end )
                             ..className = 'match'
        );
        current = end;
      } );
      if ( current < text.length ) {
        spans.add(
          new SpanElement()..text = text.substring( current )
        );
      }
      content.children = spans;
    }

    return result;
  }

  // Toggles the state of a pseudo checkbox and returns the new checked state:
  bool _toggle ( bool checked, Event event ) {
     if ( checked )
       event.target.classes.remove( 'checked' );
     else
       event.target.classes.add( 'checked' );

     return !checked;
  }

  // Toggles the specified [className] for the specified [element]:
  void _toggleClass ( element, String className ) {
    if ( element is String ) element = querySelector( element );
    var classes = element.classes;
    if ( classes.contains( className ) ) {
      classes.remove( className );
    } else {
      classes.add( className );
    }
  }

  // Select contents and given focus to the specified [element]:
  void _activate ( String element ) {
    querySelector( element )
      ..select()
      ..focus();
  }

// Returns the correct singular/plural form of "[n] [label][suffix]" for the
  // integer value [n]:
  String _plural ( int n, String label, String suffix ) {
    return "$n ${label}${(n==1)?'':suffix}";
  }

  // Verifies that the file filter is valid:
  bool _filterOk ( ) {
    bool result = true;
    if ( filterRegex ) {
      try {
        var r = new RegExp( filter );
      } catch ( exception ) { result = false; }
    }
    _errorState( '#filter', !result );

    return result;
  }

  // Returns the FileTab (if any) corresponding to [fullPath].
  FileTab _getTab ( String fullPath ) {
    for ( var aTab in tabs ) {
      if ( fullPath == aTab.fullPath ) return aTab;
    }
    return null;
  }

  // Adds the DOM elements for [tab] to the UI:
  void _addTab ( FileTab aTab ) {
    tabs.add( aTab );
    querySelector( '#tabs' ).children.add(
      aTab.createTab( _tabClicked, _tabClose )
    );
  }

  // Makes [tab] the currently active tab:
  void _setTab ( FileTab aTab, { bool forceUpdate: true } ) {
    var sameTab = (tab == aTab);
    if ( !sameTab ) {
      if ( tab != null ) {
        tab.scrollTop = querySelector( '#file2' ).scrollTop;
        tab.element.classes.remove( 'tabselected' );
      }
      tab = aTab;
      if ( tab != null ) {
        scrollTop = tab.scrollTop;
        tab.element.classes.add( 'tabselected' );
      }
    }
    if ( !sameTab || forceUpdate ) {
      lines = (tab == null) ? null : tab.lines;
      _showLines( );
    }
  }

  //-- UI Event Handlers -------------------------------------------------------

  // Handles the user clicking one of the directories:
  void _directorySelected ( MouseEvent event ) {
    _getDirectory( event.target.getAttribute( 'fullPath' ) );
  }

  // Handles the user clicking one of the files:
  void _fileSelected ( MouseEvent event ) {
    _getFile( event.target );
  }

  // Handles the filter text field value being changed:
  void _filterChanged ( Event event ) {
    filter = event.target.value;
    if ( _filterOk() ) _updateFiles();
  }

  // Handles the filter regex checkbox being clicked:
  void _filterRegexChanged ( Event event ) {
    filterRegex = _toggle( filterRegex, event );
    if ( !filter.isEmpty && _filterOk() ) _updateFiles();
  }

  // Handles the filter case checkbox being clicked:
  void _filterCaseChanged ( Event event ) {
    filterCaseSensitive = _toggle( filterCaseSensitive, event );
    if ( !filter.isEmpty ) _updateFiles();
  }

  // Handles the search text field value being changed:
  void _searchChanged ( Event event ) {
    search = event.target.value;
    _showLines( animate: false );
    if ( inFiles ) _updateFiles();
  }

  // Handles the regex checkbox being clicked:
  void _regexChanged ( Event event ) {
    regex = _toggle( regex, event );
    if ( !search.isEmpty ) {
      _showLines( );
      if ( inFiles ) _updateFiles( );
    }
  }

  // Handles the case checkbox being clicked:
  void _caseChanged ( Event event ) {
    caseSensitive = _toggle( caseSensitive, event );
    if ( !search.isEmpty ) {
      _showLines( );
      if ( inFiles ) _updateFiles( );
    }
  }

  // Handles the infiles checkbox being clicked:
  void _infilesChanged ( Event event ) {
    inFiles = _toggle( inFiles, event );
    if ( !search.isEmpty ) _updateFiles();
  }

  // Handles the contextTop checkbox being clicked:
  void _contextTopChanged ( Event event ) {
    contextTop = _toggle( contextTop, event );
    if ( !search.isEmpty ) _showLines();
  }

  // Handles the contextBottom checkbox being clicked:
  void _contextBottomChanged ( Event event ) {
    contextBottom = _toggle( contextBottom, event );
    if ( !search.isEmpty ) _showLines();
  }

  // Handles the context slider value being changed:
  void _contextChanged ( Event event ) {
    var value = event.target.value;
    context   = int.parse( value );
    querySelector( '#context2' ).text = (context < 0)? 'X': value;
    if ( !search.isEmpty ) _showLines();
  }

// Handles the filterOpen checkbox being clicked:
void _filterOpenChanged ( Event event ) {
  filterOpen = _toggle( filterOpen, event );
  _toggleClass( '.tool.left', 'open' );
  if ( filterOpen ) {
    _activate( '#filter' );
  }
}

  // Handles the searchOpen checkbox being clicked:
  void _searchOpenChanged ( Event event ) {
    searchOpen = _toggle( searchOpen, event );
    _toggleClass( '.tool.right', 'open' );
    if ( searchOpen ) {
      _activate( '#search' );
    }
  }

  // Handles the user clicking a file tab:
  void _tabClicked ( Event event ) {
    _setTab(
      _getTab( event.currentTarget.getAttribute( 'fullPath' ) ),
      forceUpdate: false
    );
  }

  // Handles the user clicking a file tab's close button:
  void _tabClose ( Event event ) {
    var tabElement = event.target.parent;
    FileTab aTab   = _getTab( tabElement.getAttribute( 'fullPath' ) );
    int i          = tabs.indexOf( aTab );
    tabElement.remove();
    tabs.remove( aTab );
    if ( tab == aTab ) {
      i = min( i, tabs.length - 1 );
      _setTab( (i >= 0)? tabs[ i ]: null );
    }
    aTab.element = null;
    event.stopPropagation();
  }
}

//-- FileTab Class -------------------------------------------------------------

class FileTab {
  // Represents the contents of a file being displayed in the app.

  // The full path name of the associated files:
  String fullPath;

  // The list of text lines contained in the file:
  List<String> lines;

  // The vertical scroll bar position:
  int scrollTop = 0;

  // The DOM element for the outermost portion of the tab:
  Element element;

  // Constructor:
  FileTab ( this.fullPath );

  // Creates the DOM element defining the tab for this file. It calls
  // [clickHandler] when the tab is clicked, and [closeHandler] when the tab's
  // close button is clicked.
  Element createTab ( clickHandler, closeHandler ) {
    element = new DivElement()
      ..className = 'tab'
      ..setAttribute( 'fullPath', fullPath )
      ..onClick.listen( clickHandler )
      ..children  = [
        new SpanElement()
          ..className = 'tabname'
          ..text      = path.basename( fullPath )
          ..title     = fullPath,
        new ImageElement( src: 'close.png' )
          ..className = 'close'
          ..title     = 'Close this tab'
          ..onClick.listen( closeHandler )
      ];

    return element;
  }
}

//-- EOF -----------------------------------------------------------------------