const { Client } = require('pg');

async function testMktRankDB() {
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb', 
    password: 'Tech1324!',
    database: 'mkt_rank_local',
    port: 5432
  });

  try {
    await client.connect();
    console.log('✅ mkt_rank_local 데이터베이스 연결 성공!\n');

    // 스키마 권한 확인
    const schemaPermResult = await client.query(`
      SELECT 
        nspname as schema_name,
        has_schema_privilege(current_user, nspname, 'CREATE') as can_create,
        has_schema_privilege(current_user, nspname, 'USAGE') as can_use
      FROM pg_namespace
      WHERE nspname = 'public'
    `);
    console.log('public 스키마 권한:', schemaPermResult.rows[0]);

    // 기존 테이블 확인
    const existingTables = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name
    `);
    
    console.log('\n기존 테이블:');
    if (existingTables.rows.length === 0) {
      console.log('  (없음)');
    } else {
      existingTables.rows.forEach(row => {
        console.log(`  - ${row.table_name}`);
      });
    }

    // ProductParser를 위한 스키마 생성 시도
    console.log('\n\nProductParser 전용 스키마 생성 시도...');
    try {
      await client.query('CREATE SCHEMA IF NOT EXISTS productparser');
      console.log('✅ productparser 스키마 생성 성공!');
      
      // 스키마에 테이블 생성
      console.log('\nproductparser 스키마에 테이블 생성 중...');
      
      await client.query(`
        CREATE TABLE IF NOT EXISTS productparser.agents (
          agent_id VARCHAR(50) PRIMARY KEY,
          pc_id VARCHAR(20) NOT NULL,
          port INTEGER NOT NULL,
          status VARCHAR(20) DEFAULT 'offline',
          platform VARCHAR(20),
          last_heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('  ✅ agents 테이블 생성 완료');
      
    } catch (schemaError) {
      console.log('❌ 스키마 생성 실패:', schemaError.message);
      
      // public 스키마에 테이블 생성 시도
      console.log('\npublic 스키마에 테이블 생성 시도...');
      try {
        await client.query(`
          CREATE TABLE IF NOT EXISTS parser_agents (
            agent_id VARCHAR(50) PRIMARY KEY,
            pc_id VARCHAR(20) NOT NULL,
            port INTEGER NOT NULL,
            status VARCHAR(20) DEFAULT 'offline',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `);
        console.log('  ✅ parser_agents 테이블 생성 성공!');
        
        // 테이블에 데이터 삽입 테스트
        await client.query(`
          INSERT INTO parser_agents (agent_id, pc_id, port, status)
          VALUES ('PC01-3001', 'PC01', 3001, 'active')
          ON CONFLICT (agent_id) DO UPDATE
          SET status = 'active'
        `);
        console.log('  ✅ 테스트 데이터 삽입 성공!');
        
        // 데이터 확인
        const result = await client.query('SELECT * FROM parser_agents');
        console.log('\n삽입된 데이터:', result.rows);
        
      } catch (tableError) {
        console.log('❌ 테이블 생성 실패:', tableError.message);
      }
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
  } finally {
    await client.end();
    console.log('\n연결 종료됨');
  }
}

// 실행
testMktRankDB();