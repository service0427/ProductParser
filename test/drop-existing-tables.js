const { Client } = require('pg');

async function dropExistingTables() {
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

    // 삭제할 테이블 목록
    const tablesToDrop = [
      'agent_performance_history',
      'agents',
      'daily_stats',
      'parsing_results',
      'parsing_results_2025_06_20',
      'parsing_results_2025_06_21',
      'test_table'
    ];

    console.log('기존 테이블 삭제 시작...\n');

    // 각 테이블 삭제
    for (const table of tablesToDrop) {
      try {
        await client.query(`DROP TABLE IF EXISTS public.${table} CASCADE`);
        console.log(`✅ ${table} 테이블 삭제 완료`);
      } catch (error) {
        console.log(`❌ ${table} 테이블 삭제 실패: ${error.message}`);
      }
    }

    // 삭제 후 남은 테이블 확인
    console.log('\n남은 테이블 확인...');
    const remainingTables = await client.query(`
      SELECT tablename 
      FROM pg_tables 
      WHERE schemaname = 'public'
      ORDER BY tablename
    `);

    if (remainingTables.rows.length === 0) {
      console.log('✅ public 스키마의 모든 테이블이 삭제되었습니다.');
    } else {
      console.log('남은 테이블:');
      remainingTables.rows.forEach(row => {
        console.log(`  - ${row.tablename}`);
      });
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
  } finally {
    await client.end();
    console.log('\n연결 종료됨');
  }
}

// 실행
console.log('⚠️  경고: productparser_db의 모든 기존 테이블을 삭제합니다.');
console.log('========================================\n');

dropExistingTables();