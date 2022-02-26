var fs = require('fs');
const http = require('http');
var url = require('url');

var filename = "";
var failFilename = "";
var getSystemData="";
var getSystemDataFail="";
var getSystemDataFailureCount=0;
var server_g = null;
var debug_g = true;
var sockets = {}, nextSocketId = 0;

const log = function( str )
{
   if ( debug_g == true )
      console.log( str );
}

const requestListener = function (req, res)
{
   req.on('close', function () {
      log( `req.on: close listener: ` );
      // Yry to remove connected listener
      //nothing server_g.removeListener( "requestListener", requestListener, this);
      //nothing server_g.removeListener( "connection", requestListener );
      // The "listener" argument must be of type function. Received type string ('requestListener')
      // server_g.removeListener( "connection", "requestListener" );
      // The "listener" argument must be of type function. Received an instance of IncomingMessage
      // server_g.removeListener( "connection", this );
      // nothingserver_g.removeListener( "connection", requestListener, this );
      //server_g.removeListener( "connection", requestListener );
      // console.log( "server_g._events: %s\n\n", server_g._events);
      // server._events: [Object: null prototype] {
      //    request: [Function: requestListener],
      //    connection: [Array],
      //    close: [Array],
      //    error: [Function]
      //  }
      //for ( let x=0; x< server_g._events.connection.length; x++)
      //{
      //    console.log( "server_g._events.connection[%s: %s\n\n", x, server_g._events.connection[x]);
      //}
      // Caused hang for second curl
      // server_g.removeListener( "request", requestListener );

   });

   // Example URL parsing
   //var adr = 'http://localhost:2025/default.htm?year=2017&month=february';
   var q = url.parse(req.url, true);

   //log(q.host); //returns 'localhost:8080'
   //log(q.pathname); //returns '/default.htm'
   //log(q.search); //returns '?year=2017&month=february'
   //var qdata = q.query; //returns an object: { year: 2017, month: 'february' }
   //log(qdata.month); //returns 'february'

   /* Request methods. Not needed, but interesting
   switch( req.method )
   {
      case 'POST':
         log("SERVER: POST");
         break;
      case 'GET':
         log("SERVER: POST");
         break;
      default:
         log("SERVER: UNKNOWN method: %s", req.method);
   }
   */

   for ( let key in q.query )
   {
      let value = q.query[ key ];
      log( `parsing key:${ key } value: ${ value }` );
      switch( key )
      {
         case "debug":
         {
            debug_g = value;
            log(`Setting debug_g to ${ debug_g}` );
            break;
         }
         case "load":
         {
            filename = value;
            // Check that the file exists locally
            // log( `SERVER: checking for file: ${ filename }` );
            if ( !fs.existsSync( filename ) )
            {
               log( `File not found: ${ filename }` );
               res.writeHead(404, { 'Content-Type': 'text/html' } );
               log( `SERVER: end\n` );
               return res.end( `404 Not Found` );
            }

            log( `SERVER: reading: ${ filename }` );
            getSystemData = "";
            getSystemData = fs.readFileSync( filename, 'utf-8')
            log( `SERVER: read length: ${ getSystemData.length }` );
            log( `SERVER: end\n` );
            res.writeHead(200, { 'Content-Type': 'text/html' } );
            return res.end();
         }
         case "loadFail":
         {
            failFilename = value;
            // Check that the file exists locally
            // log( `SERVER: checking for file: ${ filename }` );
            if ( !fs.existsSync( failFilename ) )
            {
               log( `File not found: ${ failFilename }` );
               res.writeHead(404, { 'Content-Type': 'text/html' } );
               log( `SERVER: end\n` );
               return res.end( `404 Not Found` );
            }

            log( `SERVER: reading: ${ failFilename }` );
            getSystemDataFail = "";
            getSystemDataFail = fs.readFileSync( failFilename, 'utf-8')
            log( `SERVER: read length: ${ getSystemDataFail.length }` );
            log( `SERVER: end\n` );
            res.writeHead(200, { 'Content-Type': 'text/html' } );
            return res.end();
         }
         case "failureCount":
         {
            log( `SERVER: setting failurecount to: ${ value }` );
            getSystemDataFailureCount = value;
            log( `SERVER: end\n` );
            return res.end();
            break;
         }
         default:
         {
            res.writeHead(404, { 'Content-Type': 'text/html' } );
            log( `SERVER: UNKNOWN query: ${ key }` );
            log( `SERVER: end\n` );
            return res.end( `SERVER: UNKNOWN query: ${ key }` );
         }
      }
   }

   log( `parsing pathname:${ q.pathname }` );
   switch( q.pathname )
   {
      case "/":
      {
         log( `Ignoring pathname /` );
         log( `SERVER: end\n` );
         return res.end( );
         break ;
      }
      case "/getSystemData":
      {
         let fileToSend = filename;
         let systemDataToSend = getSystemData;
         if ( getSystemDataFailureCount > 0 )
              getSystemDataFailureCount--;

         if ( getSystemDataFailureCount == 0 )
         {
            fileToSend = filename;
            systemDataToSend = getSystemData;
         } else {
            fileToSend = failFilename;
            systemDataToSend = getSystemDataFail;
         }
         if ( fileToSend == "" )
         {
            log( `No File Loaded ${ fileToSend }` );
            res.writeHead(404, { 'Content-Type': 'text/html' } );
            log( `SERVER: end\n` );
            return res.end( `404 No File Loaded` );
         }

         log( `SERVER: getSystemData filename: ${ fileToSend }` );
         res.writeHead(200, { 'Content-Type': 'text/json' } );
         log( `***** SERVER: writing length: ${ systemDataToSend.length }` );
         res.write( systemDataToSend, 'utf8', ( err ) =>
         {
           log( `Error: Writing string Data... ${ err }` );
         });
         log( `SERVER: end\n` );
         return res.end();
      }
      case "/quit":
      case "/shutdown":
      {
         if (server_g.listening)
         {
            server_g.close();

            log("SEND BYE-BYE MESSAGE AND 'FIN' TO SOCKETS");
         }

         log("GRACEFUL SHUTDOWN");
         res.writeHead(200, { 'Content-Type': 'text/html' } );
         log( `SERVER: end\n` );
         return res.end();
      }
      default:
      {
         res.writeHead(404, { 'Content-Type': 'text/html' } );
         log( `SERVER: UNKNOWN pathname: ${ q.pathname }` );
         log( `SERVER: end\n` );
         return res.end( `SERVER: UNKNOWN pathname: ${ q.pathname }` );
      }
   }
   log ( server_g);
}

Function.prototype.clone = function()
{
    var cloneObj = this;
    if (this.__isClone) {
      cloneObj = this.__clonedFrom;
    }

    var temp = function() { return cloneObj.apply(this,arguments); };
    for(var key in this) {
        temp[key] = this[key];
    }

    temp.__isClone = true;
    temp.__clonedFrom = cloneObj;

    return temp;
}

async function startServer( port, handler, callback )
{
   //let uniqueId = (new Date()).getTime().toString(36);
   let uniqueId = Date.now().toString(36);

   let uniqueHandler = handler.clone();

   // Creating http Server
   //const server = http.createServer( handler );
   const server = http.createServer( uniqueHandler );


   // Kludge to resolve socket open
   server.setMaxListeners(0);

   // The key is to instead listen for the 'error' event to be triggered:
   // listen EADDRINUSE: address already in use :::2025
   try
   {
      await new Promise((resolve, reject) =>
      {
         // Listening to http Server
         server.listen( PORT, ( err ) =>
         {
            if ( ! err )
               resolve();
         });
         server.on('connection', (socket) => {
            // Add a newly connected socket
            var socketId = nextSocketId++;
            log( `SERVER.on : connection add socketId ${ socketId }` );
            sockets[socketId] = socket;


            socket.on('close', function () {
              log( `socket.on: close socket: ${ socket} socketId: ${socketId}` );
              log(`socket ${ socketId } closed`);
              socket.destroy();
              delete sockets[socketId];

            });
            socket.on('end', function () {
              log( `socket.on: end socket: ${ socket} socketId: ${socketId}` );
              log(`socket ${ socketId } end`);
              socket.destroy();
              delete sockets[socketId];
            });


            server.once('close', ( /* NO PARM */ ) =>
            {
               // Called nCurl times after server.on('close')
              log( `SERVERonce: close  socketId: ${ socketId }` );
              // delete sockets(socket);
              // socket.destroy(socket);
            });
         });
            server.once('close', ( par ) =>
            {
               // Called nCurl times after server.on('clise')
              log( `SERVERonce Outside): close  par: ${ par }` );
              // delete sockets(socket);
              // socket.destroy(socket);
            });
         server.on('close', ( /* No PARMS */ ) =>
         {
            // happens at very end when server is shutdown
            log( `SERVER.on: CLOSE` );
         });

         server.once('error', ( err ) =>
         {
            if ( err )
            {
               //log( 'There was an error starting the server in the error listener:', err);
               reject( err );
            }
         });
      });

      // All good
      return callback(null, server);

   } catch ( e )
   {
      // Return to caller any errors
      // log('There was an error starting the server:', e );
      return callback( e, server);
   }
}

// Usage:
// export PORT=2025
// cd test
// node ./AirConServer.js
// In Second Terminal
// cd test
// curl -s -g 'http://localhost:2025/?load=testData/dataPassOn1/getSystemData.txt0'
// curl -s -g 'http://localhost:2025/?loadFail=testData/dataFailOn5/getSystemData.txt4?loadFailureCound=4'
// ../AdvAir.sh Get Blah Brightness z01 127.0.0.1 TEST_ON

// Setting up PORT
const PORT = process.env.PORT || 2025;

startServer( PORT, requestListener, ( e, server ) =>
{
   if ( e )
   {
      //log("StartServer failed. server: %s", server  );
      log(`startServer failed: ${ e }` );
   } else {
      //log("startServer passed. server: %s", server  );
      log(`Started server. Listening on PORT: ${ PORT }...` );
      server_g = server;
   }
});
