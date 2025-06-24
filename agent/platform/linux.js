const path = require('path');

module.exports = {
  chromePath: {
    executablePath: process.env.CHROME_EXECUTABLE || '/usr/bin/google-chrome',
    channel: 'chrome'
  },
  
  defaultArgs: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-gpu'
  ],
  
  getLogPath: () => {
    return process.env.LOG_PATH || path.join(process.cwd(), 'logs');
  },
  
  getChromeProfileBase: () => {
    return process.env.CHROME_PROFILE_BASE || path.join(process.cwd(), 'profiles');
  }
};