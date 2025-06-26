module.exports = {
  name: 'naver-shopping-search',
  version: '1.0.0',
  description: '네이버 쇼핑에서 키워드 검색 후 상품 정보 수집',
  
  async execute(page, params = {}) {
    const startTime = Date.now();
    const { keyword = '노트북', requestId = 'test', screenshot = false } = params;
    
    // 랜덤 지연 시간 추가 (0~2초) - 에이전트 간 경쟁 시뮬레이션
    const randomDelay = Math.random() * 2000;
    console.log(`[naver-shopping-search] Agent will add ${randomDelay.toFixed(0)}ms delay for testing`);
    await new Promise(resolve => setTimeout(resolve, randomDelay));
    
    try {
      console.log(`[naver-shopping-search] Searching for: ${keyword}`);
      
      // 네이버 쇼핑 검색 URL
      const searchUrl = `https://search.shopping.naver.com/search/all?query=${encodeURIComponent(keyword)}`;
      
      // 페이지 이동
      await page.goto(searchUrl, {
        waitUntil: 'networkidle',
        timeout: 30000
      });
      
      // 검색 결과 로드 대기
      await page.waitForSelector('[class*="basicList_list"]', { 
        timeout: 10000 
      });
      
      console.log('[naver-shopping-search] Search results loaded, extracting data...');
      
      // 상품 정보 추출 (상위 10개)
      const products = await page.evaluate(() => {
        const items = [];
        const productElements = document.querySelectorAll('[class*="basicList_item"]');
        
        for (let i = 0; i < Math.min(10, productElements.length); i++) {
          const elem = productElements[i];
          
          try {
            // 제목
            const titleElem = elem.querySelector('[class*="basicList_title"]');
            const title = titleElem ? titleElem.innerText.trim() : '';
            
            // 가격
            const priceElem = elem.querySelector('[class*="price_num"]');
            const price = priceElem ? priceElem.innerText.trim() : '';
            
            // 쇼핑몰
            const mallElem = elem.querySelector('[class*="basicList_mall"]');
            const mall = mallElem ? mallElem.innerText.trim() : '';
            
            // 리뷰 수
            const reviewElem = elem.querySelector('[class*="basicList_etc"] em');
            const reviewCount = reviewElem ? reviewElem.innerText.trim() : '0';
            
            // 이미지 URL
            const imgElem = elem.querySelector('img');
            const imageUrl = imgElem ? imgElem.src : '';
            
            // 링크
            const linkElem = elem.querySelector('a[class*="basicList_link"]');
            const link = linkElem ? linkElem.href : '';
            
            if (title && price) {
              items.push({
                title,
                price,
                mall,
                reviewCount,
                imageUrl,
                link
              });
            }
          } catch (e) {
            console.error('Error parsing product:', e);
          }
        }
        
        return items;
      });
      
      // 총 검색 결과 수
      const totalCount = await page.evaluate(() => {
        const countElem = document.querySelector('[class*="subFilter_num"]');
        return countElem ? countElem.innerText.trim() : 'N/A';
      });
      
      // 스크린샷 (옵션)
      let screenshotData = null;
      if (screenshot) {
        console.log('[naver-shopping-search] Taking screenshot...');
        screenshotData = await page.screenshot({ 
          encoding: 'base64',
          fullPage: false
        });
      }
      
      const executionTime = Date.now() - startTime;
      
      return {
        success: true,
        data: {
          keyword,
          totalCount,
          products,
          productCount: products.length,
          screenshot: screenshotData,
          collectedAt: new Date().toISOString()
        },
        executionTime,
        requestId,
        agentDelay: randomDelay,
        timestamp: new Date().toISOString()
      };
      
    } catch (error) {
      console.error('[naver-shopping-search] Error:', error);
      
      // 에러 스크린샷
      let errorScreenshot = null;
      try {
        errorScreenshot = await page.screenshot({ encoding: 'base64' });
      } catch (e) {
        console.error('Failed to take error screenshot:', e);
      }
      
      return {
        success: false,
        error: error.message,
        screenshot: errorScreenshot,
        executionTime: Date.now() - startTime,
        requestId,
        timestamp: new Date().toISOString()
      };
    }
  }
};