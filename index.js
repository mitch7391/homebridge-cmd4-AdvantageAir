"use strict";


module.exports =
{
   default: function ( api )
   {
     api.registerPlatform( "cmd4AdvantageAir", Cmd4AdvantageAir );
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
