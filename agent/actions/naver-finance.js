module.exports = {
  name: 'naver-finance',
  version: '1.0.0',
  description: '네이버 금융에서 코스피, 코스닥, 환율, 금값 데이터 수집',
  
  async execute(page, params = {}) {
    const startTime = Date.now();
    
    try {
      console.log('[naver-finance] Navigating to finance.naver.com...');
      
      // 네이버 금융 접속
      await page.goto('https://finance.naver.com', {
        waitUntil: 'networkidle',
        timeout: 30000
      });
      
      // 페이지 로드 확인
      await page.waitForSelector('.section_sise', { timeout: 10000 });
      
      console.log('[naver-finance] Page loaded, extracting data...');
      
      // 데이터 추출
      const data = await page.evaluate(() => {
        const getText = (selector) => {
          try {
            const elem = document.querySelector(selector);
            return elem ? elem.innerText.trim() : 'N/A';
          } catch (e) {
            return 'N/A';
          }
        };
        
        const getNumber = (selector) => {
          const text = getText(selector);
          return text.replace(/[^0-9,.-]/g, '');
        };
        
        // 코스피/코스닥 데이터
        const kospiData = {
          value: getNumber('.group_quot .quot_opn:nth-child(1) em'),
          change: getText('.group_quot .quot_opn:nth-child(1) .gap_rate'),
          changeRate: getText('.group_quot .quot_opn:nth-child(1) .gap_rate + span')
        };
        
        const kosdaqData = {
          value: getNumber('.group_quot .quot_opn:nth-child(2) em'),
          change: getText('.group_quot .quot_opn:nth-child(2) .gap_rate'),
          changeRate: getText('.group_quot .quot_opn:nth-child(2) .gap_rate + span')
        };
        
        // 환율 데이터 수집
        const exchangeRates = {};
        const exchangeItems = document.querySelectorAll('.group_quot.quot_exchange tbody tr');
        
        exchangeItems.forEach(item => {
          const currency = item.querySelector('th a');
          const value = item.querySelector('td em');
          
          if (currency && value) {
            const currencyCode = currency.innerText.trim().split(' ')[0];
            exchangeRates[currencyCode] = {
              value: value.innerText.trim(),
              change: item.querySelector('td:nth-child(3)')?.innerText.trim() || 'N/A'
            };
          }
        });
        
        // 원자재 데이터 (금, 원유 등)
        const commodities = {};
        const commodityItems = document.querySelectorAll('.group_quot.quot_gold tbody tr');
        
        commodityItems.forEach(item => {
          const name = item.querySelector('th a');
          const value = item.querySelector('td em');
          
          if (name && value) {
            const commodityName = name.innerText.trim();
            commodities[commodityName] = {
              value: value.innerText.trim(),
              unit: item.querySelector('td .unit')?.innerText.trim() || '',
              change: item.querySelector('td:nth-child(3)')?.innerText.trim() || 'N/A'
            };
          }
        });
        
        return {
          market: {
            kospi: kospiData,
            kosdaq: kosdaqData
          },
          exchange: exchangeRates,
          commodities: commodities,
          collectedAt: new Date().toISOString()
        };
      });
      
      // 스크린샷 (선택적)
      if (params.screenshot) {
        console.log('[naver-finance] Taking screenshot...');
        const screenshot = await page.screenshot({ 
          encoding: 'base64',
          fullPage: false,
          clip: {
            x: 0,
            y: 0,
            width: 1920,
            height: 1080
          }
        });
        data.screenshot = screenshot;
      }
      
      // 상세 데이터 수집 (선택적)
      if (params.detailed) {
        console.log('[naver-finance] Collecting detailed data...');
        
        // 시장 지표 상세
        await page.click('.group_quot .more_btn');
        await page.waitForTimeout(1000);
        
        const detailedMarket = await page.evaluate(() => {
          const details = {};
          const rows = document.querySelectorAll('.type_1 tbody tr');
          
          rows.forEach(row => {
            const name = row.querySelector('th')?.innerText.trim();
            const value = row.querySelector('td')?.innerText.trim();
            if (name && value) {
              details[name] = value;
            }
          });
          
          return details;
        });
        
        data.detailedMarket = detailedMarket;
      }
      
      console.log('[naver-finance] Data extraction completed');
      
      return {
        success: true,
        data,
        executionTime: Date.now() - startTime,
        timestamp: new Date().toISOString()
      };
      
    } catch (error) {
      console.error('[naver-finance] Error:', error);
      
      // 에러 스크린샷
      let errorScreenshot = null;
      try {
        errorScreenshot = await page.screenshot({ 
          encoding: 'base64',
          fullPage: true 
        });
      } catch (e) {
        console.error('[naver-finance] Failed to take error screenshot');
      }
      
      return {
        success: false,
        error: error.message,
        stack: error.stack,
        errorScreenshot,
        executionTime: Date.now() - startTime,
        timestamp: new Date().toISOString()
      };
    }
  }
};