const { Client } = require('pg');

async function cleanupMktRank() {
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb',
    password: 'Tech1324!',
    database: 'mkt_rank_local',
    port: 5432
  });

  try {
    await client.connect();
    console.log('✅ mkt_rank_local 연결 성공!\n');

    console.log('productparser 스키마 삭제 중...');
    
    // CASCADE로 스키마와 모든 객체 삭제
    await client.query('DROP SCHEMA IF EXISTS productparser CASCADE');
    
    console.log('✅ productparser 스키마 및 모든 객체 삭제 완료');

    // 확인
    const schemaCheck = await client.query(`
      SELECT nspname 
      FROM pg_namespace 
      WHERE nspname = 'productparser'
    `);
    
    if (schemaCheck.rows.length === 0) {
      console.log('\n확인: productparser 스키마가 완전히 삭제되었습니다.');
    }

  } catch (error) {
    console.error('❌ 오류:', error.message);
  } finally {
    await client.end();
    console.log('\n연결 종료됨');
  }
}

// 실행 확인
console.log('⚠️  경고: mkt_rank_local에서 productparser 스키마를 삭제합니다.');
console.log('계속하려면 주석을 해제하고 실행하세요.\n');

// 삭제를 실행하려면 아래 주석을 해제하세요
cleanupMktRank();