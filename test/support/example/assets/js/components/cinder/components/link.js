import CinderComponent from "../../../../../../../../assets/ts/cinder/component";

export default class Cinder$Components$Link extends CinderComponent {
  constructor(element, cinder) {
    super(element, cinder);


    this.registerEvent('click', function (event) {
      let uri = this.getAttribute('href');

      if (uri?.startsWith("/")) {
        event.preventDefault();
        cinder.transitionTo(uri);
      }

    });

  }
}
