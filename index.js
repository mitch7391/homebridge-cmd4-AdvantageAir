"use strict";

// The optional platform constructor is not called by Cmd4-only configurations.
const announcementKey = Symbol.for("homebridge-cmd4-advantageair.v4-announcement");

module.exports =
{
   default: function ( api )
   {
     api.registerPlatform( "cmd4AdvantageAir", Cmd4AdvantageAir );
     if ( !process[ announcementKey ] && typeof api.once === "function" && typeof api.removeListener === "function" )
     {
       process[ announcementKey ] = true;
       let timer;
       let stopped = false;
       const shutdown = () => {
         stopped = true;
         clearTimeout(timer);
         timer = undefined;
         api.removeListener("didFinishLaunching", launched);
         api.removeListener("shutdown", shutdown);
       };
       const launched = () => {
         if ( stopped ) return;
         timer = setTimeout(() => {
           timer = undefined;
           if ( stopped ) return;
           stopped = true;
           api.removeListener("shutdown", shutdown);
           // Homebridge supplies no public logger to the plugin initialiser.
           console.info("[AdvantageAir] A new native Advantage Air v4 beta is available!");
           console.info("[AdvantageAir] Try homebridge-advantageair@4.0.0-beta.2 (no Cmd4 required).");
           console.info("[AdvantageAir] Your existing v3 setup will continue working; migration is optional.");
           console.info("[AdvantageAir] Some legacy features are not yet supported. Read the migration guide: " +
             "https://github.com/mitch7391/homebridge-advantageair/blob/master/docs/v3-migration.md");
         }, 30000);
         timer.unref();
       };
       api.once("didFinishLaunching", launched);
       api.once("shutdown", shutdown);
     }
   }
}

// Platform definition
class Cmd4AdvantageAir
{
   constructor( log, config, api )
   {
      this.log = log;
      this.api = api;
      this.config = config;
      this.log.debug("cmd4AdvantageAir this.config %s", this.config);
   }
}
