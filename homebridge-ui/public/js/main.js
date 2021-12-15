/*global $, homebridge*/

var jq;

function checkInstallationButtonPressed( )
{
   homebridge.showSpinner();
   homebridge.request( "/checkInstallationButtonPressed" );
}
function advError( retVal )
{
   // Turn off the spinner
   homebridge.hideSpinner();

   if ( retVal.rc == true )
   {
      homebridge.toast.success( retVal.message );

   } else {
      // DO NOT TRY TO PUT THIS IN THE HTML FILE OR THE CSS FILE
      // Since bootstrap only allows 1 dialog, we solve this by
      // including our own jsquery and bootstrap. The "jq" variable
      // picks up our modal so that we can set its attributes accordingly.

      //var bs = $.fn.tooltip.Constructor.VERSION;
      //console.log(" jq version: %s", jq );
      //console.log(" Bootstrap version: %s", bs );// 4.1.3

      // Get the ID of OUR Error Modal
      let advErrorModal = jq("#advErrorModal");

      // Set the text of the message
      advErrorModal.find('.modal-body p').text( retVal.message );

      // Put a border around our modal
      advErrorModal.attr( "style", "border: 5px double orange" );

      // The height of the Div where the title is
      advErrorModal.find('.modal-header').attr( "style", "height:60px" );
      // The color of the "Error:" title
      advErrorModal.find('.modal-title').attr( "style", "color:red" );

      // The height of the modal body
      advErrorModal.find('.modal-body').attr( "style", "height:250px" );

      // When the an error event happens, open the modal
      advErrorModal.modal(
      { show:     true,   // Show the modal
        keyboard: true,   // Closes the modal when ESC pressed
        backdrop: false   // Includes a modal-backdrop element.
      });
   }
}

// STARTUP CODE
( async ( ) =>
{

   try
   {
      jq = $.noConflict( true );

      // Check Installation return event
      homebridge.addEventListener('advErrorEvent', (event) =>
      {
         advError( event.data );

      });

   }
   catch( err )
   {
      homebridge.toast.error( err.message, 'Error' );
   }

} )( );


//jquery listener
jq( '#checkInstallationButton' ).on( 'click', ( ) =>
{
   checkInstallationButtonPressed();
} );
