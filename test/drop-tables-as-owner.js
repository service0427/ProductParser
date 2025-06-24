const { Client } = require('pg');

async function dropTablesAsOwner() {
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb_db',
    password: 'Tech1324!',
    database: 'productparser_db',
    port: 5432
  });

  try {
    await client.connect();
    console.log('✅ productparser_db 연결 성공! (사용자: techb_db)\n');

    // 삭제할 테이블 목록 (techb_db가 소유한 테이블들)
    const tablesToDrop = [
      'agent_performance_history',
      'agents',
      'daily_stats',
      'parsing_results',
      'parsing_results_2025_06_20',
      'parsing_results_2025_06_21'
    ];

    console.log('techb_db 소유 테이블 삭제 시작...\n');

    // 각 테이블 삭제
    for (const table of tablesToDrop) {
      try {
        await client.query(`DROP TABLE IF EXISTS public.${table} CASCADE`);
        console.log(`✅ ${table} 테이블 삭제 완료`);
      } catch (error) {
        console.log(`❌ ${table} 테이블 삭제 실패: ${error.message}`);
      }
    }

    // test_table은 postgres가 소유하므로 삭제 시도만
    console.log('\ntest_table 삭제 시도 (postgres 소유)...');
    try {
      await client.query('DROP TABLE IF EXISTS public.test_table CASCADE');
      console.log('✅ test_table 삭제 완료');
    } catch (error) {
      console.log(`❌ test_table 삭제 실패: ${error.message}`);
    }

    // 삭제 후 남은 테이블 확인
    console.log('\n남은 테이블 확인...');
    const remainingTables = await client.query(`
      SELECT 
        tablename,
        tableowner 
      FROM pg_tables 
      WHERE schemaname = 'public'
      ORDER BY tablename
    `);

    if (remainingTables.rows.length === 0) {
      console.log('✅ public 스키마의 모든 테이블이 삭제되었습니다.');
    } else {
      console.log('남은 테이블:');
      remainingTables.rows.forEach(row => {
        console.log(`  - ${row.tablename} (소유자: ${row.tableowner})`);
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
console.log('⚠️  경고: productparser_db의 기존 테이블을 삭제합니다.');
console.log('사용자: techb_db');
console.log('========================================\n');

dropTablesAsOwner();