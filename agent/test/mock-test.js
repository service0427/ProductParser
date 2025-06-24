// WSL/Linux 환경에서 에이전트 테스트를 위한 모의 테스트

const platform = require('../platform');

console.log('===========================================');
console.log('  ProductParser Agent - Mock Test Mode');
console.log('===========================================');
console.log(`Platform: ${process.platform}`);
console.log(`Is Windows: ${platform.isWindows()}`);
console.log(`Is Linux: ${platform.isLinux()}`);
console.log('');

// 플랫폼별 설정 확인
console.log('Chrome Configuration:');
console.log(JSON.stringify(platform.getChromePath(), null, 2));
console.log('');

console.log('Profile Path (port 3001):');
console.log(platform.getProfilePath(3001));
console.log('');

// 모의 네이버 금융 데이터
const mockFinanceData = {
  market: {
    kospi: {
      value: "2,550.23",
      change: "-12.34",
      changeRate: "-0.48%"
    },
    kosdaq: {
      value: "850.45",
      change: "+5.67",
      changeRate: "+0.67%"
    }
  },
  exchange: {
    "USD": {
      value: "1,320.50",
      change: "+5.00"
    },
    "EUR": {
      value: "1,450.20",
      change: "-2.30"
    },
    "JPY(100)": {
      value: "920.30",
      change: "+1.20"
    }
  },
  commodities: {
    "금": {
      value: "82,500",
      unit: "원/g",
      change: "+500"
    },
    "WTI": {
      value: "75.23",
      unit: "달러/배럴",
      change: "-0.45"
    }
  },
  collectedAt: new Date().toISOString()
};

// 액션 테스트
if (platform.isLinux()) {
  console.log('Linux/WSL 환경 감지 - 모의 테스트 모드 실행');
  console.log('');
  
  // 모의 페이지 객체
  const mockPage = {
    goto: async (url) => {
      console.log(`[Mock] Navigating to: ${url}`);
      await new Promise(resolve => setTimeout(resolve, 1000));
    },
    waitForSelector: async (selector) => {
      console.log(`[Mock] Waiting for selector: ${selector}`);
      await new Promise(resolve => setTimeout(resolve, 500));
      return true;
    },
    evaluate: async (fn) => {
      console.log('[Mock] Evaluating page script...');
      return mockFinanceData;
    },
    screenshot: async (options) => {
      console.log('[Mock] Taking screenshot...');
      return 'base64_mock_screenshot_data';
    },
    setViewportSize: async (size) => {
      console.log(`[Mock] Setting viewport: ${size.width}x${size.height}`);
    },
    addInitScript: async () => {
      console.log('[Mock] Adding init script for stealth mode');
    },
    setDefaultTimeout: () => {},
    setDefaultNavigationTimeout: () => {}
  };
  
  // 액션 로드 및 실행
  console.log('\n--- 네이버 금융 액션 테스트 ---\n');
  
  try {
    const naverFinanceAction = require('../actions/naver-finance');
    
    console.log(`Action: ${naverFinanceAction.name} v${naverFinanceAction.version}`);
    console.log(`Description: ${naverFinanceAction.description}`);
    console.log('');
    
    // 기본 실행
    console.log('1. 기본 모드 테스트');
    const result1 = await naverFinanceAction.execute(mockPage, {});
    console.log('Result:', JSON.stringify(result1, null, 2));
    console.log('');
    
    // 스크린샷 포함
    console.log('2. 스크린샷 모드 테스트');
    const result2 = await naverFinanceAction.execute(mockPage, { screenshot: true });
    console.log('Screenshot included:', !!result2.data.screenshot);
    console.log('');
    
    // 상세 모드
    console.log('3. 상세 모드 테스트');
    mockPage.click = async () => console.log('[Mock] Clicking for detailed view');
    mockPage.waitForTimeout = async (ms) => console.log(`[Mock] Waiting ${ms}ms`);
    
    const result3 = await naverFinanceAction.execute(mockPage, { detailed: true });
    console.log('Detailed mode executed');
    
  } catch (error) {
    console.error('Action test failed:', error);
  }
  
} else {
  console.log('Windows 환경에서는 실제 Chrome을 사용합니다.');
  console.log('WSL/Linux 환경에서 이 테스트를 실행하세요.');
}

// Express 서버 모의 테스트
console.log('\n--- Express 서버 엔드포인트 테스트 ---\n');

const endpoints = [
  { method: 'GET', path: '/health', description: '상태 확인' },
  { method: 'GET', path: '/info', description: '에이전트 정보' },
  { method: 'POST', path: '/execute', description: '액션 실행' },
  { method: 'POST', path: '/update-action', description: '액션 업데이트' },
  { method: 'GET', path: '/running', description: '실행 중인 액션' },
  { method: 'GET', path: '/profile', description: '프로필 정보' }
];

console.log('Available endpoints:');
endpoints.forEach(ep => {
  console.log(`  ${ep.method.padEnd(6)} ${ep.path.padEnd(20)} - ${ep.description}`);
});

console.log('\n===========================================');
console.log('  테스트 완료');
console.log('===========================================');