var fs = require('fs');
const http = require('http');
var url = require('url');

var server_g = null;
var listener_g = null;
var debug_g = true;
var stack_g=[];

var sockets = {}, nextSocketId = 0;

const log = function( str )
{
   if ( debug_g == true )
      console.log( str );
}

const requestListener = function (req, res)
{
   req.on('close', function ()
   {
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


   // Example URL parsing
   //var adr = 'http://localhost:2025/default.htm?year=2017&month=february';
   var q = url.parse(req.url, true);
   let ended = true;

   //log(q.host); //returns 'localhost:8080'
   //log(q.pathname); //returns '/default.htm'
   //log(q.search); //returns '?year=2017&month=february'
   //var qdata = q.query; //returns an object: { year: 2017, month: 'february' }
   //log(qdata.month); //returns 'february'

   // Format of stack is:
   //    "filename": The file to loadbgetSystemData with
   //    "getSystemData": The myAirData json data read from filename,
   //    "repeat":        The number of times remaining for this data to be used.
   //
   //
   // The last record is used continiously.
   //
   // Examples
   //    curl -s -g 'http://localhost:2025?load=testData/dataPassOn1/getSystemData.txt0'
   //    curl -s -g 'http://localhost:2025?repeat=5?load=testData/dataPassOn1/getSystemData.txt0'
   //    curl -s -g 'http://localhost:2025/getDystemData'
   //    curl -s -g 'http://localhost:2025/shutdown'
   //    curl -s -g 'http://localhost:2025/quit'
   //    curl -s -g 'http://localhost:2025/reInit'
   //    curl -s -g 'http://localhost:2025?debug=1'
   //    curl -s -g 'http://localhost:2025?dumpStack'
   //
   //      Note: "repeat" must come first, otherwise 0 is used.
   //
   // Default to repeating the last record in the stack
   let repeat = 0;
   let filename;
   for ( let key in q.query )
   {
      let value = q.query[ key ];
      log( `parsing key:${ key } value: ${ value }` );
      switch( key )
      {
         case "debug":
         {
            debug_g = value;
            log( `Setting debug_g to ${ debug_g}` );
            log( `SERVER: end\n` );
            return res.end();
         }
         case "repeat":
         {
            repeat = value;
            log( `Setting repeat to ${ repeat }` );
            log( `SERVER: end\n` );
            // Do not return, possible furthet options
            ended = false;
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
               res.writeHead( 404, { 'Content-Type': 'text/html' } );
               log( `SERVER: end\n` );
               return res.end( `404 Not Found` );
            }

            log( `SERVER: reading: ${ filename }` );
            let getSystemData = fs.readFileSync( filename, 'utf-8')
            log( `SERVER: read length: ${ getSystemData.length }` );
            log( `SERVER: end\n` );
            res.writeHead( 200, { 'Content-Type': 'text/html' } );
            stack_g.push( { "filename": filename,  "getSystemData": getSystemData, "repeat": repeat } );
            log( `SERVER: end\n` );
            return res.end();
         }
         default:
         {
            res.writeHead( 404, { 'Content-Type': 'text/html' } );
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
         ended = false;
         break;
      }
      case "/reInit":
      {
         log( `Doing reInit` );
         repeat = 0;
         if ( filename ) filename = null;
         stack_g = [];
         log( `SERVER: end\n` );
         return res.end();
      }
      case "/dumpStack":
      {
         log( `Doing dumpStack` );
         res.writeHead(200, { 'Content-Type': 'text/html' } );
         log( `stack.length=${ stack_g.length }` );
         for ( let index=0; index < stack_g.length; index++ )
         {
            let record = stack_g[ index ];
            res.write( `repeat: ${ record.repeat } filename: ${record.filename }\n` );
         }
         log( `SERVER: end\n` );
         return res.end();
      }
      case "/getSystemData":
      {
         if ( stack_g.length == 0 )
         {
            log( `No File Loaded` );
            res.writeHead(404, { 'Content-Type': 'text/html' } );
            log( `SERVER: end\n` );
            return res.end( `404 No File Loaded` );
         }
         let record = stack_g.shift();
         let fileToSend = record.filename;
         let systemDataToSend = record.getSystemData;

         if ( stack_g.length == 0 )
         {
            // Don't care if less than zero
            record.repeat --;
            stack_g.unshift( record );
         } else
         {
            if ( --record.repeat > 0 )
               stack_g.unshift( record );
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
         // Interesting, while server_g and listener_g seem to be the same,
         // they are not. Listening_g properly closes the server and any
         // connections
         if (server_g.listening)
         {
            server_g.close();

            log("SERVER_G SEND BYE-BYE MESSAGE AND 'FIN' TO SOCKETS");
         }
         if (listener_g.listening)
         {
            listener_g.close();

            log("LISTENET_G SEND BYE-BYE MESSAGE AND 'FIN' TO SOCKETS");
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

   if ( ended == false )
      res.end();
   // log ( server_g);
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
   //let uniqueId = Date.now().toString(36);

   //let uniqueHandler = uniquId + handler.clone();
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
         listener_g = server.listen( PORT, ( err ) =>
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
              //delete sockets[socketId];
            });


            server.once('close', ( /* NO PARM */ ) =>
            {
               // Called nCurl times after server.on('close')
               log( `INSIDE SERVERonce: close  socketId: ${ socketId }` );
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
            log( `OUTSIDE SERVER.on: CLOSE` );
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
