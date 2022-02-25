var fs = require('fs');
const http = require('http');
var url = require('url');

var filename = "";
var getSystemData="";
var server_g = null;
//const sockets_g = new Set();
var sockets = {}, nextSocketId = 0;

const requestListener = function (req, res)
{
   // Example URL parsing
   //var adr = 'http://localhost:2025/default.htm?year=2017&month=february';
   var q = url.parse(req.url, true);

   //console.log(q.host); //returns 'localhost:8080'
   //console.log(q.pathname); //returns '/default.htm'
   //console.log(q.search); //returns '?year=2017&month=february'
   //var qdata = q.query; //returns an object: { year: 2017, month: 'february' }
   //console.log(qdata.month); //returns 'february'

   /* Request methods. Not needed, but interesting
   switch( req.method )
   {
      case 'POST':
         console.log("SERVER: POST");
         break;
      case 'GET':
         console.log("SERVER: POST");
         break;
      default:
         console.log("SERVER: UNKNOWN method: %s", req.method);
   }
   */

   switch( q.pathname )
   {
      case "/load":
      {
         filename = q.query.file;
         // Check that the file exists locally
         // console.log( `SERVER: checking for file: ${ filename }` );
         if ( !fs.existsSync( filename ) )
         {
            console.log( `File not found: ${ filename }` );
            res.writeHead(404, { 'Content-Type': 'text/html' } );
            console.log( `SERVER: end` );
            return res.end( `404 Not Found` );
         }

         console.log( `SERVER: reading: ${ filename }` );
         getSystemData = "";
         getSystemData = fs.readFileSync( filename, 'utf-8')
         console.log( `SERVER: read length: ${ getSystemData.length }` );
         console.log( `SERVER: end` );
         res.writeHead(200);
         return res.end();
      }
      case "/getSystemData":
      {
         if ( filename == "" )
         {
            console.log( `No File Loaded` );
            res.writeHead(404, { 'Content-Type': 'text/html' } );
            console.log( `SERVER: end` );
            return res.end( `404 No File Loaded` );
         }
         console.log( `SERVER: getSystemData filename: ${ filename }` );
         res.writeHead(200, { 'Content-Type': 'text/json' } );
         console.log( `***** SERVER: writing length: ${getSystemData.length}` );
         res.write( getSystemData, 'utf8', ( err ) =>
         {
           console.log( `Error: Writing string Data... ${ err }` );
         });
         console.log( `SERVER: end` );
         return res.end();
      }
      case "/quit":
      case "/shutdown":
      {
         if (server_g.listening)
         {
            server_g.close();

            // console.log("SEND BYE-BYE MESSAGE AND 'FIN' TO SOCKETS");
         }

         console.log("GRACEFUL SHUTDOWN");
         return res.end();
      }
      default:
      {
         console.log( `SERVER: UNKNOWN pathname: ${ q.pathname }` );
         console.log( `SERVER: end` );
         return res.end();
      }
   }
}


async function startServer( port, handler, callback )
{
   // Creating http Server
   const server = http.createServer( handler );


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
            sockets[socketId] = socket;

            console.log( `SERVER: connection add socket` );

            socket.on('close', function () {
             console.log('socket', socketId, 'closed');
                delete sockets[socketId];

            });

            server.once('close', () => {
              console.log( `SERVER: connection delete socket` );
              // sockets_g.delete(socket);
              socket.destroy(socket);
            });
         });

         server.once('error', ( err ) =>
         {
            if ( err )
            {
               //console.log( 'There was an error starting the server in the error listener:', err);
               reject( err );
            }
         });
      });

      // All good
      return callback(null, server);

   } catch ( e )
   {
      // Return to caller any errors
      // console.log('There was an error starting the server:', e );
      return callback( e, server);
   }
}

// Usage:
// export PORT=2025
// cd test
// node ./AirConServer.js
// In Second Terminal
// cd test
// curl -s -g 'http://localhost:2025/load?file=testData/dataFailOn5/getSystemData.txt4'
// ../AdvAir.sh Get Blah Brightness z01 127.0.0.1 TEST_ON

// Setting up PORT
const PORT = process.env.PORT || 2025;

startServer( PORT, requestListener, ( e, server ) =>
{
   if ( e )
   {
      //console.log("StartServer failed. server: %s", server  );
      console.log(`startServer failed: ${ e }` );
   } else {
      //console.log("startServer passed. server: %s", server  );
      console.log(`Started server. Listening on PORT: ${ PORT }...` );
      server_g = server;
   }
});
