module.exports = {
  chromePath: {
    executablePath: process.env.CHROME_EXECUTABLE || 
      'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    channel: undefined
  },
  
  defaultArgs: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage'
  ],
  
  getLogPath: () => {
    return process.env.LOG_PATH || 'C:\\Agents\\logs';
  },
  
  getChromeProfileBase: () => {
    return process.env.CHROME_PROFILE_BASE || 'C:\\AgentProfiles';
  }
};