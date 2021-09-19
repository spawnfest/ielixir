
import {
    JupyterFrontEnd, JupyterFrontEndPlugin
  } from '@jupyterlab/application';
  
  import './codemirror-ielixir';
  
  import '../style/index.css';
  
  /**
   * Initialization data for the extension1 extension.
   */
  const extension: JupyterFrontEndPlugin<void> = {
    id: 'ielixir',
    autoStart: true,
    requires: [],
    activate: (app: JupyterFrontEnd) =>
    {
      app.serviceManager.ready
        .then(() => {defineIElixir()});
    }
  };
  
  function defineIElixir() {
    console.log('ielixir codemirror activated');
  }
  
  
  export default extension;
