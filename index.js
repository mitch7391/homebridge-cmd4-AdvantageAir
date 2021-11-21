"use strict";


module.exports =
{
   default: function ( api )
   {
     api.registerPlatform( "cmd4-AdvAir", Cmd4AdvAir );
   }
}

// Platform definition
class Cmd4AdvAir
{
   constructor( log, config, api )
   {
      this.log = log;
      this.api = api;
      this.config = config;
      this.log.debug("cmd4-AdvAir this.config %s", this.config);
   }
}
