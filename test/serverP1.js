
const sinon = require('sinon');
const assert = require( "chai" ).assert;



// This proc fakes UIServer to think it is in a child process
// Otherwise it will not run.
process.send = function( msg ){};
var UiServer = require("../homebridge-ui/server");
delete process['send'];


describe('Test homebridge-ui/server.js Part-1', () =>
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
               "state_cmd": "bash /opt/homebrew/lib/node_modules/homebridge-cmd4-AdvantageAir/AdvAir.sh",
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


   it('Test Check #5B. See if Cmd4 is installed from node_modules', function ( done )
   {
      // Create a stub For the test to fail.
      sinon.stub( server, "getGlobalNodeModulesPathForFile").callsFake( function( fileToFind ){ if ( fileToFind == "/homebridge-cmd4/index.js" ) return null; else return `/usr/local/lib/node_modules/${ fileToFind }`; });

      //server.debug = true;


      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, "Cmd4 Plugin not installed", `Cmd4 must be installed globally in node_modules` );

      // Finish our unit test
      done( );
   });

   // Works
   it('Test Check #6 & %%5%33. No AdvAir.sh FAILS', function ( done )
   {
      // Make the test fail in the way we would want.
      server.ADVAIR_SH = '/homebridge-cmd4AdvAir/XAdvAir.sh';

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, "No AdvAir.sh script present. Looking for: <Your Global node_modules Path>/homebridge-cmd4AdvAir/XAdvAir.sh", `Must find AdvAir.sh installed globally in node_modules` );

      // Finish our unit test
      done( );
   });

   // Works
   it('Test Check #6. AdvAir.sh Passes', function ( done )
   {

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, "Passed", `All checks must pass` );

      // Finish our unit test
      done( );

   });

   it('Test Check #7 & 32. For No Cmd4 Accessories will be detected', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].platform = "XCmd4";
      config_g.platforms[0].name = "XCmd4";

      //server.debug = true;

      server.ADVAIR_SH = '/homebridge-cmd4/index.js';

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, "No Cmd4 Accessories found", `A Cmd4 Platform must be defined` );

      // Finish our unit test
      done( );
   });

   it('Test Check #8A. Constants must be an Array.', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].constants = "not an Array";

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Constants must be an array of { "key": "\${SomeKey}", "value": "some replacement string" }`, `Constants must be an Array` );

      // Finish our unit test
      done( );
   });

   it('Test Check #8B. Constants must have a key.', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].constants = [ { "blast": "${IP}", "value": "172.16.100.2" } ];

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Constant definition at index: "0" has no "key":`, `Constants must have a "key":` );

      // Finish our unit test
      done( );
   });

   it('Test Check #8C. Constants must have a value.', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].constants = [ { "key": "${IP}", "rep": "172.16.100.2" } ];

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Constant definition at index: "0" has no "value":`, `Constant must have a "value":` );

      // Finish our unit test
      done( );
   });

   it('Test Check #8D. Key must start with ${', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].constants = [ { "key": "{IP}", "value": "172.16.100.2" } ];

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Constant definition for: "{IP}" must start with "\${" for clarity.`, `Constant key must start with "\${":` );

      // Finish our unit test
      done( );
   });

   it('Test Check #8E. Key must end with }', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].constants = [ { "key": "\${IP", "value": "172.16.100.2" } ];

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Constant definition for: "\${IP" must end with "}" for clarity.`, `Constant key must not end with "}":` );

      // Finish our unit test
      done( );
   });

   it('Test Check #9. Check for no Advantage Air Accessories', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].manufacturer = "NoName";
      config_g.platforms[0].accessories[0].state_cmd = "Not_AdvAir_state_cmd";

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `No Advantage Air Accessories found`, `AdvAir accessories must be defined` );

      // Finish our unit test
      done( );
   });

   it('Test Check #10. Check See if any Advantage Air accessory has a defined name', function ( done )
   {
      // Make the test fail in the way we would want.
      config_g.platforms[0].accessories[0].name = undefined;

      //server.debug = true;

      server.checkInstallationButtonPressed( );

      assert.include( retVal_g.message, `Accessory at index: 0 accessory.name is undefined`, `Accessories must have a .name` );

      // Finish our unit test
      done( );
   });

});
