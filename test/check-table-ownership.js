const { Client } = require('pg');

async function checkTableOwnership() {
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb_pp',
    password: 'Tech1324!',
    database: 'productparser_db',
    port: 5432
  });

  try {
    await client.connect();
    console.log('✅ productparser_db 연결 성공!\n');

    // 테이블 소유자 확인
    const tables = await client.query(`
      SELECT 
        tablename,
        tableowner,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
      FROM pg_tables 
      WHERE schemaname = 'public'
      ORDER BY tablename
    `);

    console.log('테이블 소유자 정보:');
    console.log('================================');
    tables.rows.forEach(row => {
      console.log(`테이블: ${row.tablename}`);
      console.log(`  소유자: ${row.tableowner}`);
      console.log(`  크기: ${row.size}`);
      console.log('');
    });

    console.log('현재 사용자:', client.user);
    console.log('\n설명:');
    console.log('- techb_pp는 테이블을 사용할 수 있지만 소유자가 아닙니다.');
    console.log('- 테이블 소유자만 DROP TABLE을 실행할 수 있습니다.');
    console.log('- 대부분의 테이블은 techb_db가 소유하고 있습니다.');
    
    console.log('\n대안:');
    console.log('1. 테이블 소유자(techb_db 또는 postgres)로 접속하여 삭제');
    console.log('2. 기존 테이블은 그대로 두고 새로운 테이블 생성');
    console.log('3. 다른 스키마를 생성하여 사용');

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
  } finally {
    await client.end();
  }
}

checkTableOwnership();