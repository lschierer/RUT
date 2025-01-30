export default class CCBYNCLicense extends HTMLElement {
  connectedCallback() {
    this.innerHTML = `
      <p xmlns:cc="http://creativecommons.org/ns#" >
        <a rel="cc:attributionURL" href="https://www.schierer.org/luke/">Content on this site</a> by <a rel="cc:attributionURL dct:creator" property="cc:attributionName" href="https://github.com/lschierer">Luke Schierer</a> is licensed under
        <a href="https://creativecommons.org/licenses/by-nc/4.0/?ref=chooser-v1" target="_blank" rel="license noopener noreferrer" style="display:inline-block;">Creative Commons Attribution-NonCommercial 4.0 International<br/>
          <img class="cc-image" src="https://mirrors.creativecommons.org/presskit/icons/cc.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/by.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/nc.svg?ref=chooser-v1" alt="">
        </a>
      </p>
    `;
  }
}
customElements.define("license-display", CCBYNCLicense);
