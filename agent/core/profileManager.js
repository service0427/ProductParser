const { chromium } = require('playwright');
const platform = require('../platform');
const fs = require('fs').promises;
const path = require('path');

class ProfileManager {
  constructor() {
    this.profiles = new Map();
  }

  async createProfile(port) {
    const profilePath = platform.getProfilePath(port);
    const chromeConfig = platform.getChromePath();
    
    console.log(`Creating Chrome profile for port ${port}...`);
    console.log(`Profile path: ${profilePath}`);
    
    try {
      // 프로필 디렉토리 생성
      await fs.mkdir(profilePath, { recursive: true });
      
      // 브라우저 실행 옵션
      const launchOptions = {
        headless: false,
        args: [
          `--user-data-dir=${profilePath}`,
          ...platform.getBrowserArgs()
        ]
      };
      
      // Windows에서는 executablePath 필수
      if (platform.isWindows()) {
        launchOptions.executablePath = chromeConfig.executablePath;
      } else {
        launchOptions.channel = chromeConfig.channel;
      }
      
      // 브라우저 시작
      const browser = await chromium.launch(launchOptions);
      
      // 기본 설정을 위한 페이지 열기
      const page = await browser.newPage();
      
      // 한국어 설정
      await page.goto('chrome://settings/languages');
      await page.waitForTimeout(2000);
      
      // 기본 검색엔진 설정 (선택적)
      await page.goto('chrome://settings/searchEngines');
      await page.waitForTimeout(2000);
      
      await browser.close();
      
      console.log(`Profile created successfully for port ${port}`);
      
      this.profiles.set(port, {
        path: profilePath,
        createdAt: new Date(),
        port: port
      });
      
      return profilePath;
      
    } catch (error) {
      console.error(`Failed to create profile for port ${port}:`, error);
      throw error;
    }
  }
  
  async checkProfile(port) {
    const profilePath = platform.getProfilePath(port);
    
    try {
      await fs.access(profilePath);
      return true;
    } catch {
      return false;
    }
  }
  
  async getOrCreateProfile(port) {
    const exists = await this.checkProfile(port);
    
    if (!exists) {
      console.log(`Profile for port ${port} doesn't exist. Creating...`);
      await this.createProfile(port);
    } else {
      console.log(`Profile for port ${port} already exists.`);
    }
    
    return platform.getProfilePath(port);
  }
  
  async listProfiles() {
    const profileBase = platform.isWindows() 
      ? platform.getChromeProfileBase() 
      : path.join(process.cwd(), 'profiles');
      
    try {
      const files = await fs.readdir(profileBase);
      const profiles = files.filter(f => f.startsWith('port-'));
      return profiles;
    } catch (error) {
      console.error('Failed to list profiles:', error);
      return [];
    }
  }
}

module.exports = new ProfileManager();