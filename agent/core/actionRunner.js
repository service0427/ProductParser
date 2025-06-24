const { chromium } = require('playwright');
const platform = require('../platform');
const profileManager = require('./profileManager');
const fs = require('fs').promises;
const path = require('path');

class ActionRunner {
  constructor() {
    this.runningActions = new Map();
  }

  async runAction(actionName, params = {}) {
    const startTime = Date.now();
    const runId = `${actionName}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    console.log(`[ActionRunner] Starting action: ${actionName} (${runId})`);
    
    try {
      // 액션 파일 로드
      const action = await this.loadAction(actionName);
      
      if (!action) {
        throw new Error(`Action ${actionName} not found`);
      }
      
      // 실행 정보 저장
      this.runningActions.set(runId, {
        actionName,
        startTime,
        status: 'running'
      });
      
      // 브라우저 실행
      const browser = await this.launchBrowser();
      
      try {
        const page = await browser.newPage();
        
        // 기본 설정
        await this.setupPage(page);
        
        // 액션 실행
        const result = await action.execute(page, params);
        
        // 실행 시간 추가
        result.executionTime = Date.now() - startTime;
        result.runId = runId;
        
        console.log(`[ActionRunner] Action completed: ${actionName} (${result.executionTime}ms)`);
        
        return result;
        
      } finally {
        await browser.close();
      }
      
    } catch (error) {
      console.error(`[ActionRunner] Action failed: ${actionName}`, error);
      
      return {
        success: false,
        error: error.message,
        stack: error.stack,
        executionTime: Date.now() - startTime,
        runId
      };
      
    } finally {
      this.runningActions.delete(runId);
    }
  }
  
  async loadAction(actionName) {
    const actionPath = path.join(__dirname, '..', 'actions', `${actionName}.js`);
    
    try {
      await fs.access(actionPath);
      
      // 캐시 제거 (개발 중 수정사항 반영)
      delete require.cache[require.resolve(actionPath)];
      
      const action = require(actionPath);
      
      // 액션 유효성 검증
      if (!action.execute || typeof action.execute !== 'function') {
        throw new Error('Action must have an execute function');
      }
      
      return action;
      
    } catch (error) {
      console.error(`Failed to load action ${actionName}:`, error.message);
      return null;
    }
  }
  
  async launchBrowser() {
    const config = require('../config.json');
    const profilePath = await profileManager.getOrCreateProfile(config.port);
    const chromeConfig = platform.getChromePath();
    
    const launchOptions = {
      headless: false,
      args: [
        `--user-data-dir=${profilePath}`,
        ...platform.getBrowserArgs()
      ],
      // 느린 모션 (디버깅용, 필요시 제거)
      // slowMo: 100
    };
    
    // Windows에서는 executablePath 필수
    if (platform.isWindows()) {
      launchOptions.executablePath = chromeConfig.executablePath;
    } else {
      launchOptions.channel = chromeConfig.channel;
    }
    
    console.log('[ActionRunner] Launching browser...');
    
    return await chromium.launch(launchOptions);
  }
  
  async setupPage(page) {
    // 기본 뷰포트 설정
    await page.setViewportSize({ width: 1920, height: 1080 });
    
    // 네비게이터 속성 수정 (자동화 탐지 우회)
    await page.addInitScript(() => {
      // webdriver 속성 제거
      Object.defineProperty(navigator, 'webdriver', {
        get: () => undefined
      });
      
      // Chrome 속성 추가
      window.chrome = {
        runtime: {}
      };
      
      // 플러그인 추가
      Object.defineProperty(navigator, 'plugins', {
        get: () => [1, 2, 3, 4, 5]
      });
      
      // 언어 설정
      Object.defineProperty(navigator, 'language', {
        get: () => 'ko-KR'
      });
      
      Object.defineProperty(navigator, 'languages', {
        get: () => ['ko-KR', 'ko', 'en-US', 'en']
      });
    });
    
    // 기본 타임아웃 설정
    page.setDefaultTimeout(30000);
    page.setDefaultNavigationTimeout(30000);
  }
  
  async saveAction(actionName, code) {
    const actionPath = path.join(__dirname, '..', 'actions', `${actionName}.js`);
    
    try {
      // actions 디렉토리 확인
      const actionsDir = path.dirname(actionPath);
      await fs.mkdir(actionsDir, { recursive: true });
      
      // 액션 파일 저장
      await fs.writeFile(actionPath, code, 'utf8');
      
      console.log(`[ActionRunner] Action saved: ${actionName}`);
      
      return true;
      
    } catch (error) {
      console.error(`Failed to save action ${actionName}:`, error);
      return false;
    }
  }
  
  getRunningActions() {
    return Array.from(this.runningActions.entries()).map(([id, info]) => ({
      id,
      ...info
    }));
  }
}

module.exports = new ActionRunner();