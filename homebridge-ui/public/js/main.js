/* global homebridge */

function checkInstallationButtonPressed() {
  homebridge.showSpinner();

  homebridge
    .request('/checkInstallationButtonPressed')
    .catch((error) => {
      homebridge.hideSpinner();
      homebridge.toast.error(error.message, 'Error');
    });
}

function advError(retVal) {
  homebridge.hideSpinner();

  if (retVal.rc === true) {
    homebridge.toast.success(retVal.message);
  } else {
    homebridge.toast.error(retVal.message, 'Configuration Check');
  }
}

(async () => {
  try {
    homebridge.addEventListener('advErrorEvent', (event) => {
      advError(event.data);
    });

    const checkButton = document.getElementById(
      'checkInstallationButton',
    );

    if (checkButton === null) {
      throw new Error('Check Configuration button was not found.');
    }

    checkButton.addEventListener(
      'click',
      checkInstallationButtonPressed,
    );
  } catch (error) {
    homebridge.toast.error(error.message, 'Error');
  }
})();
