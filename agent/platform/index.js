const path = require('path');

module.exports = {
  getChromePath: () => {
    if (process.platform === 'win32') {
      return require('./windows').chromePath;
    }
    return require('./linux').chromePath;
  },
  
  getProfilePath: (port) => {
    if (process.platform === 'win32') {
      return `C:\\AgentProfiles\\port-${port}`;
    }
    return path.join(process.cwd(), 'profiles', `port-${port}`);
  },
  
  getBrowserArgs: () => {
    const baseArgs = [
      '--disable-blink-features=AutomationControlled',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-popup-blocking',
      '--disable-notifications',
      '--disable-gpu-sandbox'
    ];
    
    if (process.platform === 'win32') {
      return require('./windows').defaultArgs.concat(baseArgs);
    }
    return require('./linux').defaultArgs.concat(baseArgs);
  },
  
  isWindows: () => process.platform === 'win32',
  isLinux: () => process.platform === 'linux'
};