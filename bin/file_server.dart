//------------------------------------------------------------------------------
//
//  File server for use with the file browser client (file_browser.dart) which
//  supports a simple REST API for retrieving the directories, files and text
//  file contents for the configured root directory tree.
//
//  Copyright 2014 by David C. Morrill
//
//------------------------------------------------------------------------------
// TODO: Look into supporting github source code repositories as a proxy server
// TODO: Discard non-existent root directories with a warning message
//------------------------------------------------------------------------------

//-- Imports -------------------------------------------------------------------

import 'dart:async';
import "dart:convert";
import "dart:collection";
import "dart:io";
import "package:path/path.dart" as path;
import 'package:http_server/http_server.dart';

//-- Constants -----------------------------------------------------------------

// The host and port to bind to:
//String host = '10.0.0.6';
String host = '127.0.0.1';
int port    = 8090;

//-- Global Data ---------------------------------------------------------------

// The set of valid file extensions to serve:
var validExtensions = new Set.from( [
  '.bat', '.c', '.coffee', '.cpp','.css', '.h', '.hpp', '.htm', '.html',
  '.java', '.js', '.py', '.rb', '.txt', '.xml'
] );

// The list of file system roots:
List<String> roots = [ '' ];

// The mapping from shorthand root names to actual root paths (only used if
// there is more than one root):
Map<String,String> rootMap = {};

// The amount of time before search results expire:
Duration searchExpiration = new Duration( minutes: 10 );

// Cache mapping search pattern/file name values to search results:
Map<String,List> searchCache = {};

//-- Server main function ------------------------------------------------------
void main ( List<String> args ) {

  // Process the configuration file (if any):
  try {
    Map config = JSON.decode(
      new File( 'file_server.json' ).readAsStringSync()
    );
    if ( config[ 'host' ]       != null ) host = config[ 'host' ];
    if ( config[ 'port' ]       != null ) port = config[ 'port' ];
    if ( config[ 'types' ]      != null ) validExtensions = config[ 'types' ];
    if ( config[ 'expiration' ] != null )
      searchExpiration = new Duration( minutes: config[ 'expiration' ] );
    var config_roots = config[ 'roots' ];
    if ( config_roots != null ) {
      if ( config_roots is String )    roots = [ config_roots ];
      else if ( config_roots is List ) roots = config_roots;
      else print(
        "Unrecognized 'roots' value type in config file. It should be a string "
        "or\nlist of strings specifying directories. Using the default value."
      );
    }
  } on FileSystemException { /* Ignore it, since config not required */ }

  // Allow the roots specification to be overridden/set from the command line:
  if ( args.length >= 1 ) roots = args;

  _buildRootMap();

  var webFiles = new VirtualDirectory( '../web' )..jailRoot = false;

  runZoned(
    ( ) {
      HttpServer.bind( host, port ).then( ( server ) {
        print( 'Server running on ${host}:${port}' );
        print( '\nDirectories being served:' );
        roots.forEach( ( root ) => print( '  $root' ) );
        print( '\nFile types being served:' );
        validExtensions.forEach( ( ext ) => print( '  $ext' ) );
        server.listen( ( HttpRequest request ) {
          var segments = request.uri.pathSegments;
          if ( segments.length >= 1 ) {
            String command = segments[0];
            String method  = request.method;
            if ( (command == 'dir') || (command == 'file') ) {
              if ( method != 'GET' )
                _invalidRequest( request );
              else if ( command == 'dir' )
                _directoryHandler( request );
              else
                _fileHandler( request );
            } else {
              webFiles.serveRequest( request );
            }
          } else {
            _invalidRequest( request );
          }
        } );
      } );
    },
    onError: ( error, stackTrace ) => print( 'Oh no! $error $stackTrace' )
  );
}

// Build the mapping from shorthand root names to root paths:
void _buildRootMap ( ) {
  roots = new LinkedHashSet.from(
    roots.map( ( root ) => path.normalize( path.absolute( root ) ) )
  ).toList();
  roots.forEach( ( root ) {
      if ( new Directory( root ).existsSync() ) {
        var name  = '';
        var parts = path.split( root );
        for ( var i = parts.length - 1; i >= 0; i-- ) {
          if ( !name.isEmpty ) name = '_$name';
          name = '${parts[ i ]}$name';
          if ( rootMap[ name ] == null ) {
            rootMap[ name ] = root;
            break;
          }
        }
      } else {
        print( '$root is not a directory' );
      }
  } );
}

// Handles a request for the contents of a specified directory path:
void _directoryHandler ( HttpRequest request ) {
  request.response
      ..statusCode = HttpStatus.OK
      ..headers.contentType = new ContentType( 'text', 'plain',
                                               charset: 'UTF-8' );
  Finder filter      = new Finder( _getParameter( request, 'filter' ) );
  Finder search      = new Finder( _getParameter( request, 'search' ) );
  List<String> items = [];
  String directory   = _getPath( request );
  if ( directory.isEmpty && (roots.length > 1) ) {
    _sendPseudoRoots( request );
  } else {
    new Directory( directory ).list().listen(
      ( FileSystemEntity item ) {
        String name = path.basename( item.path );
        if ( item is Directory ) {
          items.add( '+$name' );
        } else if ( _isValidFileType( name ) && filter.matches( name ) ) {
          if ( search.isEmpty )  {
            items.add( '-$name' );
          } else if ( search.matchesContents( item.path ) ) {
            items.add( '-$name' );
          }
        }
      },
      onDone: () {
        request.response
          ..write( JSON.encode( items ) )
          ..close();
      }
    );
  }
}

// Handles a request for the contents of a specified file path:
void _fileHandler ( HttpRequest request ) {
  String fileName = _getPath( request );
  if ( !_isValidPath( fileName ) || !_isValidFileType( fileName ) ) {
    _invalidRequest( request );
  } else {
    File file = new File( fileName );
    file.exists().then( ( exists ) {
      if ( exists ) {
        request.response
          ..statusCode = HttpStatus.OK
          ..headers.contentType = new ContentType( 'text', 'plain',
                                                   charset: 'UTF-8' );
        file.openRead().pipe( request.response );
      } else _invalidRequest( request );
    } );
  }
}

// When there are multiple roots and the requested path is empty, send the
// pseudo root names back to the client:
void _sendPseudoRoots ( HttpRequest request ) {
  request.response
    ..write( JSON.encode( rootMap.keys.map( ( root ) => '+$root' ).toList() ) )
    ..close();
}

// Checks if a specified file is within one of the root subtrees:
bool _isValidPath ( apath ) =>
  roots.any( ( root ) => path.isWithin( root, apath ) );

// Checks if a specified file is one of the acceptable file types:
bool _isValidFileType ( String fileName ) =>
  validExtensions.contains( path.extension( fileName ).toLowerCase() );

// Returns an invalid request response to a client:
void _invalidRequest ( HttpRequest request ) {
  request.response
    ..statusCode = HttpStatus.NOT_FOUND
    ..write( '404: Requested path not found' )
    ..close();
}

// Gets the path associated with a client request:
String _getPath ( HttpRequest request ) {
  var apath = _getParameter( request, 'path');
  if ( roots.length == 1 )
    return path.join( roots[0], apath );

  var parts = path.split( apath );
  if ( !parts.isEmpty ) {
    var root = rootMap[ parts[0] ];
    if ( root != null )
      return path.join(
        root, path.joinAll( parts.getRange( 1, parts.length ) )
      );
  }
  return '';
}

String _getParameter ( HttpRequest request, String name ) {
  var parameters = request.uri.queryParameters;
  var value      = '';
  if ( parameters != null ) {
     value = parameters[ name ];
     if ( value == null ) value = '';
  }

  return value;
}

//-- Finder Class --------------------------------------------------------------

int searchCacheHits1 = 0;  // DEBUG
int searchCacheHits2 = 0;  // DEBUG
typedef bool Matcher( String item );

class Finder {

  // The original filter description:
  String description;

  // The finder function:
  Matcher matches;

  // The value being looked for:
  dynamic value;

  // Constructor:
  Finder ( String find ) {
    description = find;
    matches     = _matchAny;
    if ( find.length >= 2 ) {
      bool caseSensitive = find.substring( 1, 2 ) == 't';
      String pattern     = find.substring( 2 );
      if ( find.substring( 0, 1 ) == 't' ) {
        try {
          value   = new RegExp( pattern, caseSensitive: caseSensitive );
          matches = _matchRegex;
        } catch ( exception ) { }
      } else {
        if ( caseSensitive ) {
          value   = pattern;
          matches = _matchCaseSensitive;
        } else {
          value   = pattern.toLowerCase();
          matches = _matchCaseInsensitive;
        }
      }
    }
  }

  // Matches any value:
  bool _matchAny ( String  item ) {
    return true;
  }

  // Matches a regular expression:
  bool _matchRegex ( String  item ) {
    return value.hasMatch( item );
  }

  // Matches a case sensitive string:
  bool _matchCaseSensitive ( String  item ) {
    return item.contains( value );
  }

  // Matches a case insensitive string:
  bool _matchCaseInsensitive ( String  item ) {
    return item.toLowerCase().contains( value );
  }

  // Returns whether the item has a pattern to find:
  bool get isEmpty => (value == null);

  // Checks if the item matches the contents of the specified [file]:
  bool matchesContents ( String file ) {
    // TODO: Figure out a way to eliminate the use of 'sync' calls and return a
    // Future result.
    FileStat stat;

    // Get the current time for use with the cache logic:
    var now = new DateTime.now();

    // Create a unique key from the search pattern and file name:
    var key = '${description.length}:$description$file';

    // See if there is a cache entry for it:
    List values = searchCache[ key ];
    if ( values != null ) {

      // If the cache value has not yet expired, return the cached match value:
      if ( now.isBefore( values[0] ) ) {
        searchCacheHits1++;
        return values[2];
      }

      // Otherwise if the file time stamp has not changed, we can update the
      // cache entry and return the original match result:
      stat = FileStat.statSync( file );
      if ( values[1] == stat.modified ) {
        values[0] = now.add( searchExpiration );
        searchCacheHits2++;
        return values[2];
      }
    } else {
      stat   = FileStat.statSync( file );
      values = new List( 3 );
      searchCache[ key ] = values;
      if ( (searchCache.length % 100) == 0 ) {
        print( 'cache size: ${searchCache.length} '
               'hits1: $searchCacheHits1 '
               'hits2: $searchCacheHits2' );
      }
      // TODO: Implement cache size check here...
    }

    // Check to see if the file contents match the pattern:
    bool result;
    try {
      result = matches( new File( file ).readAsStringSync() );
    } catch ( exception ) {
      // If we couldn't read it, we can't serve it, so say it didn't match:
      result = false;
    }

    // Update the cache entries:
    values[0] = now.add( searchExpiration );
    values[1] = stat.modified;
    values[2] = result;

    return result;
  }
}

//-- EOF -----------------------------------------------------------------------