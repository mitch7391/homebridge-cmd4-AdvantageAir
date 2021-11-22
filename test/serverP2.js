
const sinon = require('sinon');
const assert = require( "chai" ).assert;



// This proc fakes UIServer to think it is in a child process
// Otherwise it will not run.
process.send = function( msg ){};
var UiServer = require("../homebridge-ui/server");
delete process['send'];


describe('Test homebridge-ui/server.js Part-2', () =>
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

   it('Test Check #11. Check See if any Advantage Air accessory has a defined displayName', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].displayName = undefined;

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Accessory at index: 0 "Theatre_Room" has no displayName`, `Accessory must have a displayName` );

      // Finish our unit test
      done( );
   });

   it('Test Check #12. Duplicate Display Names', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[1] =
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
            };

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Accessory: "Theatre_Room"'s displayName is defined twice`, `No duplicate displayName's allowed` );

      // Finish our unit test
      done( );
   });

   it('Test Check #13. The state_cmd must be defined for the Air accessory', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].state_cmd = undefined;

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `No state_cmd for: "Theatre_Room"`, `state_cmd defined must be defined` );

      // Finish our unit test
      done( );
   });

   it('Test Check #14. See if the state_cmd does not match the cmd4AdvAir.sh', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].state_cmd = "Not what its supposed to be";

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Invalid state_cmd for: "Theatre_Room". It should be:\n/opt/homebrew/lib/node_modules/homebridge-cmd4AdvAir/AdvAir.sh`, `state_cmd defined must be defined properly` );

      // Finish our unit test
      done( );
   });

   it('Test Check #15. See if the state_cmd_suffix is defined for the Air accessory', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].state_cmd_suffix = undefined;

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `No state_cmd_suffix for: "Theatre_Room". It must at least contain an IP.`, `state_cmd_suffix defined must be defined` );

      // Finish our unit test
      done( );
   });

   it('Test Check #16. The state_cmd_suffix must have an IP for the Air accessory', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].state_cmd_suffix = "192.168.2.X";

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `state_cmd_suffix has no IP for: "Theatre_Room" state_cmd_suffix: 192.168.2.X`, `state_cmd_suffix has an IP` );

      // Finish our unit test
      done( );
   });

   it('Test Check #17A. The state_cmd_suffix must have a zone or noSensors EXCEPT Fan accessories', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0] =
            {
              "type": "Fan",
               "displayName": "Fan",
               "name": "Fan",
               "manufacturer": "Advantage Air Australia",
               "model": "e-zone",
               "queue": "7",
               "on": 0,
               "polling":
               [
                   { "characteristic": "on" }
               ],
               "state_cmd": "bash /opt/homebrew/lib/node_modules/homebridge-cmd4AdvAir/AdvAir.sh",
               "state_cmd_suffix": "${IP} TEST_CMD4"
            };


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Passed`, `state_cmd_suffix For Fan does not need Z0x or NoSensors` );

      // Finish our unit test
      done( );
   });

   it('Test Check #17B. The state_cmd_suffix must have a zone or noSensors EXCEPT Thermostat accessories', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0] =
            {
              "type": "Thermostat",
               "displayName": "Thermostat",
               "name": "Thermostat",
               "manufacturer": "Advantage Air Australia",
               "model": "e-zone",
               "queue": "7",
               "currentTemperature": 22,
               "polling":
               [
                   { "characteristic": "currentTemperature" }
               ],
               "state_cmd": "bash /opt/homebrew/lib/node_modules/homebridge-cmd4AdvAir/AdvAir.sh",
               "state_cmd_suffix": "${IP} TEST_CMD4"
            };


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Passed`, `state_cmd_suffix For Thermostat does not need Z0x or NoSensors` );

      // Finish our unit test
      done( );
   });

   it('Test Check #17C. The state_cmd_suffix must have a zone or noSensors for Sensors accessories', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].state_cmd_suffix = "${IP} TEST_CMD4";


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `state_cmd_suffix has no zone for: "Theatre_Room"`, `state_cmd_suffix For Sensors must have "Z0x" or NoSensors` );

      // Finish our unit test
      done( );
   });

   it('Test Check #18. queueTypes must be an array.', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].queueTypes = "Not an Srray";


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `queueTypes is not an Array`, `queueTypes is an Array` );

      // Finish our unit test
      done( );
   });

   it('Test Check #20. Duplicate queues must not exist.', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].queueTypes = [
                { "queue": "7", "queueType": "WoRm" },
                { "queue": "7", "queueType": "WoRm" }
            ];


      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Duplicate queue found: 7`, `No duplicate queue types allowed` );

      // Finish our unit test
      done( );
   });
});
