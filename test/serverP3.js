
const sinon = require('sinon');
const assert = require( "chai" ).assert;



// This proc fakes UIServer to think it is in a child process
// Otherwise it will not run.
process.send = function( msg ){};
var UiServer = require("../homebridge-ui/server");
delete process['send'];


describe('Test homebridge-ui/server.js Part-3', () =>
{
   let homebridge = [];
   let config_g = {};
   var server;
   var retVal_g;

   beforeEach(() => {
      config_g =
      {  "bridge":
         {
            "name": "Homebridge 1938",
            "username": "0E:DA:6A:09:19:38",
            "port": 51431,
            "pin": "444-44-444"
         },
         "platforms": [{
            "platform": "Cmd4",
            "name": "Cmd4",
            "statusMsg": true,
            "timeout": 5000,
            "queueTypes": [
                { "queue": "7", "queueType": "WoRm" }
            ],
            "constants": [
                { "key": "${IP}", "value": "192.168.2.65" },
                { "key": "${PORT}", "value": "8091" }
            ],
            "accessories": [
            {
              "type": "TemperatureSensor",
               "subType": "tempSensor2",
               "displayName": "Theatre_Room",
               "currentTemperature": 22.2,
               "statusFault": "NO_FAULT",
               "name": "Theatre_Room",
               "manufacturer": "Advantage Air Australia",
               "model": "e-zone",
               "serialNumber": "Fujitsu e-zone2",
               "queue": "7",
               "polling":
               [
                   { "characteristic": "currentTemperature" }
               ],
               "state_cmd": "bash /opt/homebrew/lib/node_modules/homebridge-cmd4AdvAir/AdvAir.sh",
               "state_cmd_suffix": "z02 ${IP} TEST_CMD4"
            }]
         }]
      };

      if ( server )
         server = null;

      retVal_g = { rc: true, message: "" };

      process.send = function( msg ){};
      server = new UiServer();
      delete process['send' ];

      // Create a stub so that advError sets our global error message variable.
      sinon.stub( server, "advError").callsFake( function( retVal ){ retVal_g = retVal });
      // Create a stub so  that updateConfiguration returns our config.json look alike
      sinon.stub( server, "updateConfigFirstTime").callsFake( function( firstTime ){ server.config = config_g });

      // Create a function of the UiServer to exit when called.
      server.goodbye = function( ) { process.exit(0); }

   });
   afterEach(() => {
      // MaxListenersExceededWarning: Possible EventEmitter memory leak detected
      process.removeAllListeners();

      sinon.restore();
   });
   after(function () {
      //server.goodbye();
   });

   it('Test Check #21. Duplicate queues must not exist.', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].queue = undefined


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `No queue defined for: "Theatre_Room"`, `Queue name must be defined` );

      // Finish our unit test
      done( );
   });

   it('Test Check #22. queue name must be an string.', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].queue = 15


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `queue for: "Theatre_Room" is not a string`, `Queue must be a string` );

      // Finish our unit test
      done( );
   });

   it('Test Check #23. queue must be defined in queueTypes.', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].queue = "not 7";


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `For: "Theatre_Room" No matching queue: "not 7" in queueTypes`, `Queue must be defined in queueTypes` );

      // Finish our unit test
      done( );
   });

   it('Test Check #24A. For AdvAir accessories polling must be defined.', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].polling = undefined;


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Polling for: "Theatre_Room" is not an Array or Boolean`, `Polling must not be undefined for AdvAir accessories` );

      // Finish our unit test
      done( );
   });

   it('Test Check #24B. For AdvAir accessories polling must be a Boolean with false (Fails).', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].polling = false;


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Polling for: "Theatre_Room" is not an Array or Boolean`, `Polling with a boolean=false must fail for AdvAir accessories` );

      // Finish our unit test
      done( );
   });

   it('Test Check #24B. For AdvAir accessories polling must be a Boolean with true (Passes).', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].polling = true;


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Passed`, `Polling must be a boolean=true for AdvAir accessories` );

      // Finish our unit test
      done( );
   });

   it('Test Check #24B. For AdvAir accessories polling must be an Array.', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].polling = [ { characteristic: "On" } ];


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Passed`, `Polling must be an Array for AdvAir accessories` );

      // Finish our unit test
      done( );
   });
});
